//
//  MessageInboxFilter.swift
//  iMessage
//

import Foundation

enum MessageInboxFilter: Hashable {
    case messages
    case unknownSenders
    case junk
    case recentlyDeleted
}
