//
//  ReviewService.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 1/6/26.
//

import Foundation
import Supabase
import Combine
import UIKit

class ReviewService: ObservableObject {
    @Published var courseReviews: [Review] = [] // reviews for spec. course
    @Published var userReviews: [Review] = []
    
    var skipNetWorkCalls = false
    
    private let supabase = SupabaseManager.shared.client
    
        
        func uploadPhoto(_ image: UIImage, userId: UUID) async throws -> String {
            guard let imageData = image.jpegData(compressionQuality: 0.7) else {
                throw NSError(domain: "ReviewService", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Failed to compress image"])
            }
            
            let fileName = "\(userId.uuidString)/\(UUID().uuidString).jpg"
            let filePath = fileName
            
            try await supabase.storage
                .from("review-photos")
                .upload(filePath, data: imageData, options: FileOptions(contentType: "image/jpeg"))
            
            let publicURL = try supabase.storage
                .from("review-photos")
                .getPublicURL(path: filePath)
            
            return publicURL.absoluteString
        }
        
        func saveReview(_ review: Review) async throws {
            try await supabase
                .from("reviews")
                .insert(review)
                .execute()
        }
        
        func fetchReviews(for courseId: Int) async throws -> [Review] {
            let response = try await supabase
                .from("reviews")
                .select()
                .eq("course_id", value: courseId)
                .order("created_at", ascending: false)
                .execute()
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let fetchedReviews = try decoder.decode([Review].self, from: response.data)
            
            await MainActor.run {
                self.courseReviews = fetchedReviews
            }
            
            return fetchedReviews
        }
        
        func fetchReviewsByCourseName(_ courseName: String) async throws -> [Review] {
            
            if skipNetWorkCalls {
                return courseReviews
            }
            
            let response = try await supabase
                .from("reviews")
                .select()
                .eq("course_name", value: courseName)
                .order("created_at", ascending: false)
                .execute()
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let fetchedReviews = try decoder.decode([Review].self, from: response.data)
            
            await MainActor.run {
                self.courseReviews = fetchedReviews
            }
            
            return fetchedReviews
        }
        
        func fetchUserReviews() async throws -> [Review] {
            
            let userId = try await supabase.auth.session.user.id
            let response = try await supabase
                .from("reviews")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let fetchedReviews = try decoder.decode([Review].self, from: response.data)
            
            await MainActor.run {
                self.userReviews = fetchedReviews
            }
            
            return fetchedReviews
        }
        
        func getAverageRating(for courseId: Int) async throws -> Double {
            let reviews = try await fetchReviews(for: courseId)
            guard !reviews.isEmpty else { return 0 }
            let sum = reviews.reduce(0) { $0 + $1.rating }
            return Double(sum) / Double(reviews.count)
        }
        
        func deleteReview(_ review: Review) async throws {
            try await supabase
                .from("reviews")
                .delete()
                .eq("id", value: review.id.uuidString)
                .execute()
        }
        
        private struct ReviewUpdatePayload: Encodable {
            let username: String
            let rating: Int
            let comment: String
            let course_name: String
            let course_id: Int?
            let photo_urls: [String]?
        }
        
       func updateReview(_ review: Review) async throws {
            let payload = ReviewUpdatePayload(
                username: review.username,
                rating: review.rating,
                comment: review.comment,
                course_name: review.courseName,
                course_id: review.courseId,
                photo_urls: review.photoUrls
            )
            
            try await supabase
                .from("reviews")
                .update(payload)
                .eq("id", value: review.id.uuidString)
                .execute()
        }
    }
