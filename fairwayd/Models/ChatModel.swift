//
//  ChatModel.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 8/6/26.
//
import Combine
import CoreLocation
import Foundation

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    
    enum Role: String {
        case user
        case assistant
    }
    
    let role: Role
    let createdAt = Date()
    var text: String
    
}

struct HistoryEntry: Codable {
    let role: String
    let content: String
}

struct ChatContext: Codable {
    let skillLevel: SkillLevel?
    let latitude: Double?
    let longitude: Double?
}

struct ChatRequest: Codable {
    let message: String
    let history: [HistoryEntry]
    let context: ChatContext
}

struct StreamState: Codable {
    let type: String
    let text: String?
    let name: String?
    let message: String?
}

