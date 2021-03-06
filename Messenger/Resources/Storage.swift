//
//  Storage.swift
//  Messenger
//
//  Created by Дмитрий Болучевских on 03.02.2022.
//

import Foundation
import FirebaseStorage

///Allows you to get, fetch and upload files to firebase storage
final class StorageManager {
    static let shared = StorageManager()
    
    private init() {}
    
    let metadata = StorageMetadata()
    
    private let storage = Storage.storage().reference()
    
    public typealias UploadpictureComplition = (Result<String, Error>) -> Void

    /// Upload picture to firebase storage and returns complition with url string to download
    public func uploadProfilePicture(with data: Data, fileName: String, complition: @escaping UploadpictureComplition) {
        storage.child("images/\(fileName)").putData(data, metadata: nil) { [weak self] metadata, error in
            
            guard let strongSelf = self else {
                return
            }
            
            guard error == nil else {
                // failed
                print("failed to upload data to firebase for picture")
                complition(.failure(StorageErrors.failedToUpload))
                return
            }
            
            strongSelf.storage.child("images/\(fileName)").downloadURL { url, error in
                guard let url = url else {
                    print("failed to get download url")
                    complition(.failure(StorageErrors.failedToGetDownloadUrl))
                    return
                }
                
                let urlString = url.absoluteString
                print("download url returned: \(urlString)")
                complition(.success(urlString))
            }
        }
    }
    
    /// Upload image that will be sent in a conversation message
    public func uploadMessagePhoto(with data: Data, fileName: String, complition: @escaping UploadpictureComplition) {
        storage.child("message_images/\(fileName)").putData(data, metadata: nil) { [weak self] metadata, error in
            guard error == nil else {
                // failed
                print("failed to upload data to firebase for picture")
                complition(.failure(StorageErrors.failedToUpload))
                return
            }
            
            self?.storage.child("message_images/\(fileName)").downloadURL { url, error in
                guard let url = url else {
                    print("failed to get download url")
                    complition(.failure(StorageErrors.failedToGetDownloadUrl))
                    return
                }
                
                let urlString = url.absoluteString
                print("download url returned: \(urlString)")
                complition(.success(urlString))
            }
        }
    }
    
    /// Upload voicemessage that will be sent in a conversation message
    public func uploadMessageVoice(with fileUrl: URL, fileName: String, complition: @escaping UploadpictureComplition) {
        
        guard let voiceData = NSData(contentsOf: fileUrl) as Data? else {
            return
        }
        
        storage.child("message_voices/\(fileName)").putData(voiceData, metadata: nil) { [weak self] metadata, error in
            guard error == nil else {
                // failed
                print("failed to upload data to firebase for voice")
                complition(.failure(StorageErrors.failedToUpload))
                return
            }
            
            self?.storage.child("message_voices/\(fileName)").downloadURL { url, error in
                guard let url = url else {
                    print("failed to get download url")
                    complition(.failure(StorageErrors.failedToGetDownloadUrl))
                    return
                }
                
                let urlString = url.absoluteString
                print("download url returned: \(urlString)")
                complition(.success(urlString))
            }
        }
    }
    
    /// Upload video that will be sent in a conversation message
    public func uploadMessageVideo(with fileUrl: URL, fileName: String, complition: @escaping UploadpictureComplition) {
        metadata.contentType = "video/quicktime"
        guard let videoData = NSData(contentsOf: fileUrl) as Data? else {
            return
        }
        storage.child("message_videos/\(fileName)").putData(videoData, metadata: nil) { [weak self] metadata, error in
            guard error == nil else {
                // failed
                print("failed to upload videofile to firebase: \(String(describing: error))")
                complition(.failure(StorageErrors.failedToUpload))
                return
            }
            
            self?.storage.child("message_videos/\(fileName)").downloadURL { url, error in
                guard let url = url else {
                    print("failed to get download url")
                    complition(.failure(StorageErrors.failedToGetDownloadUrl))
                    return
                }
                
                let urlString = url.absoluteString
                print("download url returned: \(urlString)")
                complition(.success(urlString))
            }
        }
    }
    
    public enum StorageErrors: Error {
        case failedToUpload
        case failedToGetDownloadUrl
    }
    
    public func downloadUrl(for path: String, complition: @escaping (Result<URL, Error>) -> Void) {
        let reference = storage.child(path)
        
        reference.downloadURL { url, error in
            guard let url = url, error == nil else {
                complition(.failure(StorageErrors.failedToGetDownloadUrl))
                return
            }
            
            complition(.success(url))
        }
    }
}
