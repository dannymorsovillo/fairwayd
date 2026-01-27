//
//  Review.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 11/29/25.
//
import Foundation

struct Review: Identifiable, Codable, Equatable {
    let id: UUID           // unique, now non-optional
    let userId: UUID?
    let username: String
    let rating: Int        // 1–5 stars
    let comment: String
    let courseName: String
    let courseId: Int?
    let createdAt: Date?
    let photoUrls: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case username
        case rating
        case comment
        case courseName = "course_name"
        case courseId = "course_id"
        case createdAt = "created_at"
        case photoUrls = "photo_urls"
    }
}
