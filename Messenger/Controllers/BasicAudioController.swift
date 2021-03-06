//
//  BasicAudioController.swift
//  Messenger
//
//  Created by Дмитрий Болучевских on 09.02.2022.
//

import UIKit
import AVFoundation
import MessageKit

/// The `BasicAudioController` update UI for current audio cell that is playing a sound
/// and also creates and manage an `AVAudioPlayer` states, play, pause and stop.
open class BasicAudioController: NSObject, AVAudioPlayerDelegate {
    open var audioPlayer: AVAudioPlayer?
    open weak var playingCell: AudioMessageCell?
    open var playingMessage: MessageType?
    open private(set) var state: PlayerState = .stopped
    public weak var messageCollectionView: MessagesCollectionView?
    internal var progressTimer: Timer?

    // MARK: - Init Methods
    public init(messageCollectionView: MessagesCollectionView) {
        self.messageCollectionView = messageCollectionView
        super.init()
    }

    open func configureAudioCell(_ cell: AudioMessageCell, message: MessageType) {
        if playingMessage?.messageId == message.messageId, let collectionView = messageCollectionView, let player = audioPlayer {
            playingCell = cell
            cell.progressView.progress = (player.duration == 0) ? 0 : Float(player.currentTime/player.duration)
            cell.playButton.isSelected = (player.isPlaying == true) ? true : false
            guard let displayDelegate = collectionView.messagesDisplayDelegate else {
                fatalError("MessagesDisplayDelegate has not been set.")
            }
            cell.durationLabel.text = displayDelegate.audioProgressTextFormat(Float(player.currentTime), for: cell, in: collectionView)
        }
    }

    /// Used for play sound
    open func playSound(for message: MessageType, in audioCell: AudioMessageCell) {
        switch message.kind {
        case .audio(let item):
            playingCell = audioCell
            playingMessage = message
            let group = DispatchGroup()
            group.enter()
            URLSession.shared.dataTask(with: item.url) { [weak self] data, _, _ in
                guard let strongSelf = self,
                      let data = data,
                      let player = try? AVAudioPlayer(data: data) else {
                    print("Failed to create audio player for URL: \(item.url)")
                    return
                }
                strongSelf.audioPlayer = player
                print("Должно быть 1")
                group.leave()
            }.resume()
            group.wait()
            
            print("Должно быть 2")
            audioPlayer?.prepareToPlay()
            audioPlayer?.delegate = self
            audioPlayer?.play()
            state = .playing
            audioCell.playButton.isSelected = true  // show pause button on audio cell
            startProgressTimer()
            audioCell.delegate?.didStartAudio(in: audioCell)
        default:
            print("BasicAudioPlayer failed play sound because given message kind is not Audio")
        }
    }

    /// Used to pause the audio sound
    open func pauseSound(for message: MessageType, in audioCell: AudioMessageCell) {
        audioPlayer?.pause()
        state = .pause
        audioCell.playButton.isSelected = false // show play button on audio cell
        progressTimer?.invalidate()
        if let cell = playingCell {
            cell.delegate?.didPauseAudio(in: cell)
        }
    }

    /// Stops any ongoing audio playing if exists
    open func stopAnyOngoingPlaying() {
        guard let player = audioPlayer, let collectionView = messageCollectionView else {
            return
        }
        player.stop()
        state = .stopped
        if let cell = playingCell {
            cell.progressView.progress = 0.0
            cell.playButton.isSelected = false
            guard let displayDelegate = collectionView.messagesDisplayDelegate else {
                fatalError("MessagesDisplayDelegate has not been set.")
            }
            cell.durationLabel.text = displayDelegate.audioProgressTextFormat(Float(player.duration), for: cell, in: collectionView)
            cell.delegate?.didStopAudio(in: cell)
        }
        progressTimer?.invalidate()
        progressTimer = nil
        audioPlayer = nil
        playingMessage = nil
        playingCell = nil
    }

    /// Resume a currently pause audio sound
    open func resumeSound() {
        guard let player = audioPlayer, let cell = playingCell else {
            stopAnyOngoingPlaying()
            return
        }
        player.prepareToPlay()
        player.play()
        state = .playing
        startProgressTimer()
        cell.playButton.isSelected = true // show pause button on audio cell
        cell.delegate?.didStartAudio(in: cell)
    }

    // MARK: - Fire Methods
    @objc private func didFireProgressTimer(_ timer: Timer) {
        guard let player = audioPlayer, let collectionView = messageCollectionView, let cell = playingCell else {
            return
        }
        // check if can update playing cell
        if let playingCellIndexPath = collectionView.indexPath(for: cell) {
            let currentMessage = collectionView.messagesDataSource?.messageForItem(at: playingCellIndexPath, in: collectionView)
            if currentMessage != nil && currentMessage?.messageId == playingMessage?.messageId {
                // messages are the same update cell content
                cell.progressView.progress = (player.duration == 0) ? 0 : Float(player.currentTime/player.duration)
                guard let displayDelegate = collectionView.messagesDisplayDelegate else {
                    fatalError("MessagesDisplayDelegate has not been set.")
                }
                cell.durationLabel.text = displayDelegate.audioProgressTextFormat(Float(player.currentTime), for: cell, in: collectionView)
            } else {
                // if the current message is not the same with playing message stop playing sound
                stopAnyOngoingPlaying()
            }
        }
    }

    // MARK: - Progress Timer
    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
        progressTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(BasicAudioController.didFireProgressTimer(_:)), userInfo: nil, repeats: true)
    }

    // MARK: - AVAudioPlayerDelegate
    open func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stopAnyOngoingPlaying()
    }

    open func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        stopAnyOngoingPlaying()
    }
}

