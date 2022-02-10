//
//  ChatViewController.swift
//  Messenger
//
//  Created by Дмитрий Болучевских on 03.02.2022.
//

import UIKit
import MessageKit
import InputBarAccessoryView
import SDWebImage
import AVFoundation
import AVKit
import CoreLocation

final class ChatViewController: MessagesViewController {
    
    private var recordSession: AVAudioSession?
    private var audioRecorder: AVAudioRecorder?
    lazy var audioController = BasicAudioController(messageCollectionView: messagesCollectionView)
    
    private var senderPhotoURL: URL?
    private var otherUserPhotoURL: URL?
    
    public static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .long
        formatter.locale = .current
        return formatter
    }()
    
    public let otherUserEmail: String
    private var conversationId: String?
    public var isNewConversation = false

    private var messages: [Message] = []
    
    private var selfSender: Sender? {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return nil
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        
        return Sender(photoURL: "",
                      senderId: safeEmail,
                      displayName: "Me")
    }
    
    init(with email: String, id: String?) {
        self.conversationId = id
        self.otherUserEmail = email
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .red
        
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messagesCollectionView.messageCellDelegate = self
        messageInputBar.delegate = self
        
        // Voice recprd feach
        recordSession = AVAudioSession.sharedInstance()
        
        if let recordSession = recordSession {
            do {
                try recordSession.setCategory(.playAndRecord, mode: .default, options: .mixWithOthers)
                try recordSession.setActive(true, options: .notifyOthersOnDeactivation)
                recordSession.requestRecordPermission { [unowned self] allowed in
                    DispatchQueue.main.async {
                        if !allowed {
                            // failed to record!
                            setupInputButton(whereVoiceIs: false)
                            
                        } else {
                            // can record
                            setupInputButton(whereVoiceIs: true)
                        }
                    }
                }
            } catch {
                // failed to record!
            }
        }
    }
    
    private func setupInputButton(whereVoiceIs voice: Bool) {
        let button = InputBarButtonItem()
        button.setSize(CGSize(width: 35, height: 35), animated: false)
        button.setImage(UIImage(systemName: "paperclip"), for: .normal)
        button.onTouchUpInside { [weak self] _ in
            self?.presentInputActionSheet()
        }
        let recordButton = InputBarButtonItem()
        recordButton.setSize(CGSize(width: 35, height: 35), animated: false)
        recordButton.setImage(UIImage(systemName: "mic"), for: .normal)
        if voice {
            recordButton.tintColor = .systemBlue
            recordButton.isEnabled = true
            let longGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongTapOnButton))
            recordButton.addGestureRecognizer(longGestureRecognizer)
        } else {
            recordButton.tintColor = .systemGray
            recordButton.isEnabled = false
        }

        messageInputBar.setLeftStackViewWidthConstant(to: 72, animated: false)
        messageInputBar.setStackViewItems([button, recordButton], forStack: .left, animated: false)
    }
    
    private func presentInputActionSheet() {
        let actionSheet = UIAlertController(title: "Attach Media",
                                            message: "What would you like to attach?",
                                            preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Photo",
                                            style: .default,
                                            handler: { [weak self] _ in
                                                self?.presentPhotoActionSheet()
                                            }))
        actionSheet.addAction(UIAlertAction(title: "Video",
                                            style: .default,
                                            handler: { [weak self] _ in
                                                self?.presentVideoActionSheet()
                                            }))
        actionSheet.addAction(UIAlertAction(title: "Location",
                                            style: .default,
                                            handler: { [weak self] _ in
                                                self?.presentLocationPicker()
                                            }))
        actionSheet.addAction(UIAlertAction(title: "Cancel",
                                            style: .cancel,
                                            handler: {  _ in
                                                
                                            }))
        
        present(actionSheet, animated: true)
    }
    
    private func presentLocationPicker() {
        let vc = LocationPickerViewController(coordinates: nil)
        vc.title = "Pick Location"
        vc.navigationItem.largeTitleDisplayMode = .never
        vc.complition = { [weak self] selectedCoordinates in
            
            guard let strongSelf = self else {
                return
            }
            
            guard let messageId = strongSelf.createMessageId(),
                  let conversationId = strongSelf.conversationId,
                  let name = strongSelf.title,
                  let selfSender = strongSelf.selfSender else {
                return
            }
            
            let longitude: Double = selectedCoordinates.longitude
            let latitude: Double = selectedCoordinates.latitude
            
            print("long=\(longitude), lat=\(latitude)")
            
            let location = Location(location: CLLocation(latitude: latitude, longitude: longitude),
                                 size: .zero)
            let message = Message(sender: selfSender,
                                  messageId: messageId,
                                  sentDate: Date(),
                                  kind: .location(location))
            
            DatabaseManager.shared.sendMessage(to: conversationId, otherUserEmail: strongSelf.otherUserEmail, name: name, newMessage: message) { success in
                if success {
                    print("Sent location message")
                } else {
                    print("Failed to send location message")
                }
            }
        }
        navigationController?.pushViewController(vc, animated: true)
        
    }
    
    private func presentPhotoActionSheet() {
        let actionSheet = UIAlertController(title: "Attach Photo",
                                            message: "Where would you like to attach a photo from?",
                                            preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Camera",
                                            style: .default,
                                            handler: { [weak self] _ in
                                                let picker = UIImagePickerController()
                                                picker.sourceType = .camera
                                                picker.delegate = self
                                                picker.allowsEditing = true
                                                self?.present(picker, animated: true)
                                            }))
        actionSheet.addAction(UIAlertAction(title: "Photo Library",
                                            style: .default,
                                            handler: { [weak self] _ in
                                                let picker = UIImagePickerController()
                                                picker.sourceType = .photoLibrary
                                                picker.delegate = self
                                                picker.allowsEditing = true
                                                self?.present(picker, animated: true)
                                            }))
        actionSheet.addAction(UIAlertAction(title: "Cancel",
                                            style: .cancel,
                                            handler: nil))
        
        present(actionSheet, animated: true)
    }
    
    private func presentVideoActionSheet() {
        let actionSheet = UIAlertController(title: "Attach Video",
                                            message: "Where would you like to attach a video from?",
                                            preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Camera",
                                            style: .default,
                                            handler: { [weak self] _ in
                                                let picker = UIImagePickerController()
                                                picker.sourceType = .camera
                                                picker.delegate = self
                                                picker.mediaTypes = ["public.movie"]
                                                picker.videoQuality = .typeMedium
                                                picker.allowsEditing = true
                                                self?.present(picker, animated: true)
                                            }))
        actionSheet.addAction(UIAlertAction(title: "Library",
                                            style: .default,
                                            handler: { [weak self] _ in
                                                let picker = UIImagePickerController()
                                                picker.sourceType = .photoLibrary
                                                picker.delegate = self
                                                picker.mediaTypes = ["public.movie"]
                                                picker.videoQuality = .typeMedium
                                                picker.allowsEditing = true
                                                self?.present(picker, animated: true)
                                            }))
        actionSheet.addAction(UIAlertAction(title: "Cancel",
                                            style: .cancel,
                                            handler: nil))
        
        present(actionSheet, animated: true)
    }
    
    private func listenForMessages(id: String, shouldScrollToBottom: Bool) {
        DatabaseManager.shared.getAllMessagesForConversation(with: id) { [weak self] result in
            switch result {
            case .success(let messages):
                guard !messages.isEmpty else {
                    return
                }
                self?.messages = messages
                DispatchQueue.main.async {
                    self?.messagesCollectionView.reloadDataAndKeepOffset()
                    if shouldScrollToBottom {
                        self?.messagesCollectionView.scrollToLastItem()
                    }
                    
                }
            case .failure(let error):
                print("Failed to get messages: \(error)")
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super .viewDidAppear(animated)
        messageInputBar.inputTextView.becomeFirstResponder()
        if let conversationId = conversationId {
            listenForMessages(id: conversationId, shouldScrollToBottom: true)
        }
    }

}

extension ChatViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    func sendVoiceMessage(withVoice fileUrl: URL, andDurationd duration: Float) {
        guard let messageId = createMessageId(),
              let conversationId = conversationId,
              let name = title,
              let selfSender = selfSender else {
            return
        }
        
        let fileName = "voice_message_\(messageId.replacingOccurrences(of: " ", with: "-")).m4a"
        
        //Upload voice
        
        StorageManager.shared.uploadMessageVoice(with: fileUrl, fileName: fileName) { [weak self] result in
            //
            guard let strongSelf = self else {
                return
            }
            
            switch result {
            case .success(let urlString):
                // Ready to send message
                print("Uploaded Message Voice: \(urlString)")
                
                guard let url = URL(string: urlString) else {
                    return
                }
                
                let audio = Audio(url: url,
                                  duration: duration,
                                  size: .zero)
                
                let message = Message(sender: selfSender,
                                      messageId: messageId,
                                      sentDate: Date(),
                                      kind: .audio(audio))
                
                // Send Message
                DatabaseManager.shared.sendMessage(to: conversationId,
                                                   otherUserEmail: strongSelf.otherUserEmail,
                                                   name: name,
                                                   newMessage: message) { success in
                    if success {
                        print("Sent voice message")
                    } else {
                        print("Failed to send photo message")
                    }
                }
                
            case .failure(let error):
                print("Message voice upload error: \(error)")
            }
        }
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        guard let messageId = createMessageId(),
              let conversationId = conversationId,
              let name = title,
              let selfSender = selfSender else {
            return
        }
        
        if let image = info[.editedImage] as? UIImage, let imageData = image.pngData() {
            let fileName =  "photo_message_\(messageId.replacingOccurrences(of: " ", with: "-")).png"
            
            // Upload image
            
            StorageManager.shared.uploadMessagePhoto(with: imageData, fileName: fileName) { [weak self] result in
                guard let strongSelf = self else {
                    return
                }
                switch result {
                case .success(let urlString):
                    // Ready to send message
                    print("Uploaded Message Photo: \(urlString)")
                    
                    guard let url = URL(string: urlString),
                          let placeholder = UIImage(systemName: "plus") else {
                        return
                    }
                    
                    let media = Media(url: url,
                                      image: nil,
                                      placeholderImage: placeholder,
                                      size: .zero)
                    
                    let message = Message(sender: selfSender,
                                          messageId: messageId,
                                          sentDate: Date(),
                                          kind: .photo(media))

                    // Send Message
                    DatabaseManager.shared.sendMessage(to: conversationId,
                                                       otherUserEmail: strongSelf.otherUserEmail,
                                                       name: name,
                                                       newMessage: message) { success in
                        if success {
                            print("Sent photo message")
                        } else {
                            print("Failed to send photo message")
                        }
                    }
                case .failure(let error):
                    print("Message photo upload error: \(error)")
                }
            }
        } else if let videoUrl = info[.mediaURL] as? URL {
            let fileName =  "photo_message_\(messageId.replacingOccurrences(of: " ", with: "-")).mov"
            
            // Upload video
            StorageManager.shared.uploadMessageVideo(with: videoUrl, fileName: fileName) { [weak self] result in
                guard let strongSelf = self else {
                    return
                }
                switch result {
                case .success(let urlString):
                    // Ready to send message
                    print("Uploaded Message Video: \(urlString)")
                    
                    guard let url = URL(string: urlString),
                          let placeholder = UIImage(systemName: "plus") else {
                        return
                    }
                    
                    let media = Media(url: url,
                                      image: nil,
                                      placeholderImage: placeholder,
                                      size: .zero)
                    
                    let message = Message(sender: selfSender,
                                          messageId: messageId,
                                          sentDate: Date(),
                                          kind: .video(media))

                    // Send Message
                    DatabaseManager.shared.sendMessage(to: conversationId,
                                                       otherUserEmail: strongSelf.otherUserEmail,
                                                       name: name,
                                                       newMessage: message) { success in
                        if success {
                            print("Sent video message")
                        } else {
                            print("Failed to send video message")
                        }
                    }
                case .failure(let error):
                    print("Message video upload error: \(error)")
                }
            }
        }
    }
}

extension ChatViewController: InputBarAccessoryViewDelegate {
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        guard !text.replacingOccurrences(of: " ", with: "").isEmpty,
              let selfSender = selfSender,
              let messageId = createMessageId() else {
            return
        }
        
        print("Sending: \(text)")
        let message = Message(sender: selfSender,
                              messageId: messageId,
                              sentDate: Date(),
                              kind: .text(text))
        
        // Send message
        DispatchQueue.main.async { [weak self] in
            self?.messageInputBar.inputTextView.text = nil
        }
        if isNewConversation {
            // create convo in database
            DatabaseManager.shared.createNewConversation(with: otherUserEmail,
                                                         name: title ?? "User",
                                                         firstMessage: message) { [weak self] success in
                if success {
                    print("message sent")
                    self?.isNewConversation = false
                    let newConversationId = "conversation_\(message.messageId)"
                    self?.conversationId = newConversationId
                    self?.listenForMessages(id: newConversationId, shouldScrollToBottom: true)
                } else {
                    print("failed send")
                }
            }
        } else {
            guard let conversationId = conversationId,
                  let name = title else {
                return
            }
            // apend to existing conversation data
            DatabaseManager.shared.sendMessage(to: conversationId,
                                               otherUserEmail: otherUserEmail,
                                               name: name,
                                               newMessage: message) { success in
                if success {
                    print("Message sent")
                } else {
                    print("Failed to sed")
                }
            }
        }
    }
    
    private func createMessageId() -> String? {
        // date, otherUserEmail, senderEmail, randomInt
        
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            return nil
        }
        
        let safeCurrentEmail = DatabaseManager.safeEmail(emailAddress: currentUserEmail)
        let dateString = Self.dateFormatter.string(from: Date())
        let newIdentifier = "\(otherUserEmail)_\(safeCurrentEmail)_\(dateString)"
        
        print("created message id: \(newIdentifier)")
        
        return newIdentifier
    }
}

extension ChatViewController: MessagesDataSource, MessagesLayoutDelegate, MessagesDisplayDelegate {
    func currentSender() -> SenderType {
        if let sender = selfSender {
            return sender
        }
        fatalError("Self Sender is nil, email should be cached")
    }
    
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        return messages[indexPath.section]
    }
    
    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        return messages.count
    }
    
    func configureMediaMessageImageView(_ imageView: UIImageView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        guard let message = message as? Message else {
            return
        }
        
        switch message.kind {
        case .photo(let media):
            guard let imageUrl = media.url else {
                return
            }
            imageView.sd_setImage(with: imageUrl, completed: nil)
        default:
            break
        }
    }
    
    func backgroundColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        let sender = message.sender
        if sender.senderId == selfSender?.senderId {
            // our message that we've sent
            return .link
        }
        return .secondarySystemBackground
    }
    
    func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        
        let sender = message.sender
        if sender.senderId == selfSender?.senderId {
            // show our image
            if let currentUserImageURL = senderPhotoURL {
                avatarView.sd_setImage(with: currentUserImageURL, completed: nil)
            } else {
                
                guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
                    return
                }
                let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
                let path = "images/\(safeEmail)_profile_picture.png"
                // fetch url
                StorageManager.shared.downloadUrl(for: path) { [weak self] result in
                    switch result {
                    case .success(let url):
                        self?.senderPhotoURL = url
                        DispatchQueue.main.async {
                            avatarView.sd_setImage(with: url, completed: nil)
                        }
                    case .failure(let error):
                        print("\(error)")
                    }
                }
            }
        } else {
            // other user image
            if let otherUserImageURL = otherUserPhotoURL {
                avatarView.sd_setImage(with: otherUserImageURL, completed: nil)
            } else {
                let email = otherUserEmail
                
                let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
                let path = "images/\(safeEmail)_profile_picture.png"
                // fetch url
                StorageManager.shared.downloadUrl(for: path) { [weak self] result in
                    switch result {
                    case .success(let url):
                        self?.otherUserPhotoURL = url
                        DispatchQueue.main.async {
                            avatarView.sd_setImage(with: url, completed: nil)
                        }
                    case .failure(let error):
                        print("\(error)")
                    }
                }
            }
        }
    }
}

extension ChatViewController: MessageCellDelegate {
    func didTapMessage(in cell: MessageCollectionViewCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else {
            return
        }
        let message = messages[indexPath.section]
        
        switch message.kind {
        case .location(let locationData):
            let coordinates = locationData.location.coordinate
            let vc = LocationPickerViewController(coordinates: coordinates)
            vc.title = "Location"
            navigationController?.pushViewController(vc, animated: true)
        default:
            break
        }
    }
    
    func didTapPlayButton(in cell: AudioMessageCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell),
                    let message = messagesCollectionView.messagesDataSource?.messageForItem(at: indexPath, in: messagesCollectionView) else {
                        print("Failed to identify message when audio cell receive tap gesture")
                        return
                }
                guard audioController.state != .stopped else {
                    // There is no audio sound playing - prepare to start playing for given audio message
                    audioController.playSound(for: message, in: cell)
                    return
                }
                if audioController.playingMessage?.messageId == message.messageId {
                    // tap occur in the current cell that is playing audio sound
                    if audioController.state == .playing {
                        audioController.pauseSound(for: message, in: cell)
                    } else {
                        audioController.resumeSound()
                    }
                } else {
                    // tap occur in a difference cell that the one is currently playing sound. First stop currently playing and start the sound for given message
                    audioController.stopAnyOngoingPlaying()
                    audioController.playSound(for: message, in: cell)
                }
    }
    
    func didTapImage(in cell: MessageCollectionViewCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else {
            return
        }
        let message = messages[indexPath.section]
        
        switch message.kind {
        case .photo(let media):
            guard let imageUrl = media.url else {
                return
            }
            let vc = PhotoViewerViewController(with: imageUrl)
            navigationController?.pushViewController(vc, animated: true)
        case .video(let media):
            guard let videoUrl = media.url else {
                return
            }
            
            let vc = AVPlayerViewController()
            vc.player = AVPlayer(url: videoUrl)
            vc.player?.play()
            present(vc, animated: true)
        default:
            break
        }
    }
}

extension ChatViewController: AVAudioRecorderDelegate {
    @objc func handleLongTapOnButton(sender : UIGestureRecognizer) {
        if sender.state == .began {
            print("Start voice record")
            startRecording()
            
        } else if sender.state == .ended {
            print("Stop voice record and send it")
            finishRecording(success: true)
        }
    }
    
    private func startRecording() {
        let audioFilename = getDocumentsDirectory().appendingPathComponent("recording.m4a")
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
        } catch {
            finishRecording(success: false)
        }
    }
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    func finishRecording(success: Bool) {
        audioRecorder?.stop()
        audioRecorder = nil
        
        if success {
            // Send message
            print("Send record")
            let pathToAudio = getDocumentsDirectory().appendingPathComponent("recording.m4a")
            do {
                let durationOfVoice = try AVAudioPlayer(contentsOf: pathToAudio).duration
                guard durationOfVoice > 0 else {
                    print("Failed: Auido is very short")
                    return
                }
                sendVoiceMessage(withVoice: pathToAudio, andDurationd: Float(durationOfVoice))
            } catch {
                // error
            }
            print(pathToAudio)
            
        } else {
            print("Failed to record audio")
        }
    }
}
