//
//  Storage.swift
//  Messenger
//
//  Created by Дмитрий Болучевских on 03.02.2022.
//

import Foundation
import FirebaseStorage

final class StorageManager {
    static let shared = StorageManager()
    
    private let storage = Storage.storage().reference()
    
    
    /*
     /image/markussafaron-gmail-com_profile_picrure.png
     */
    public typealias UploadpictureComplition = (Result<String, Error>) -> Void

    /// Upload picture to firebase storage and returns complition with url string to download
    public func uploadProfilePicture(with data: Data, fileName: String, complition: @escaping UploadpictureComplition) {
        storage.child("images/\(fileName)").putData(data, metadata: nil) { metadata, error in
            guard error == nil else {
                // failed
                print("failed to upload data to firebase for picture")
                complition(.failure(StorageErrors.failedToUpload))
                return
            }
            
            self.storage.child("images/\(fileName)").downloadURL { url, error in
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
