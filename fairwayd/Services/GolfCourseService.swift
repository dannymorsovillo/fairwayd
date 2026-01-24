//
// GolfCourseService.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 12/17/25.
//
import Foundation
import CoreLocation
import Supabase
import Combine


struct SearchRequest: Codable {
    let query: String
}

struct CourseIDRequest: Codable {
    let courseId: Int
}

struct RegisterForm: Codable {
    let email: String
}

struct ActivatePayload: Codable {
    let token: String
}


enum APIError: Error, LocalizedError {
    case missingAPIKey
    case invalidURL
    case badStatus(Int, String)
    case decodeFailed
    case supabaseError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Missing API key."
        case .invalidURL:
            return "Invalid URL."
        case .badStatus(let code, let body):
            return "Request failed with status \(code). \(body)"
        case .decodeFailed:
            return "Failed to decode API response."
        case .supabaseError(let message):
            return "Supabase error: \(message)"
        }
    }
}

final class GolfCourseService: ObservableObject {
    @Published var courses: [GolfCourse] = []
    private let supabase = SupabaseManager.shared.client

    // MARK: - /v1/search
    @MainActor
    func searchCourses(query: String) async throws -> [GolfCourse] {
        let request = SearchRequest(query: query)
        let bodyData = try JSONEncoder().encode(request)
        let searchResponse: SearchResponse =  try await supabase.functions.invoke(
            "golf-course-search",
            options: FunctionInvokeOptions(
                body: bodyData
            )
        )
        
        
        print("Decoded courses:", searchResponse.courses.map { $0.titleText })
        self.courses = searchResponse.courses
        return searchResponse.courses
    }

    // MARK: - /v1/courses/{id}
    func fetchCourse(id: Int) async throws -> GolfCourse {
        let request = CourseIDRequest(courseId: id)
        let bodyData = try JSONEncoder().encode(request)
        let courseResponse: CourseResponse = try await supabase.functions.invoke(
            "golf-course-search",
            options: FunctionInvokeOptions(
                body:bodyData
            )
        )
        return courseResponse.course
    }
    
    // MARK: - /v1/users (register)
    func registerUser(email: String) async throws {
        let url = URL(string: "\(APIConfig.supabaseURL)/v1/users")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(RegisterForm(email: email))

        let (data, resp) = try await URLSession.shared.data(for: req)
        
        guard let http = resp as? HTTPURLResponse else { return }
        if !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIError.badStatus(http.statusCode, body)
        }
    }

    // MARK: - /v1/users/activated (activate)
    func activateUser(token: String) async throws {
        let url = URL(string: "\(APIConfig.supabaseURL)/v1/users/activated")!
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(ActivatePayload(token: token))

        let (data, resp) = try await URLSession.shared.data(for: req)
        
        guard let http = resp as? HTTPURLResponse else { return }
        if !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIError.badStatus(http.statusCode, body)
        }
    }
}

