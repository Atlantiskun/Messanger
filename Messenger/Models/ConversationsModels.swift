//
//  ConversationsModels.swift
//  Messenger
//
//  Created by Дмитрий Болучевских on 08.02.2022.
//

import Foundation

struct Conversation {
    let id: String
    let name: String
    let otherUserEmail: String
    let latestMessage: LatestMessage
}

struct LatestMessage {
    let date: String
    let text: String
    let isRead: Bool
}
