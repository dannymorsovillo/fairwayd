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
    
}

