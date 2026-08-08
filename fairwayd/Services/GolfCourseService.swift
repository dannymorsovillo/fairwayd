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


final class GolfCourseService: ObservableObject {
    @Published var courses: [GolfCourse] = []
    
    private let supabase = SupabaseManager.shared.client

    // MARK: - /v1/search
    @MainActor
    func searchCourses(query: String) async throws -> [GolfCourse] {
        let request = SearchRequest(query: query)
        let bodyData = try JSONEncoder().encode(request)
        
        let searchResponse: SearchResponse
        do {
            searchResponse =  try await supabase.functions.invoke(
                "golf-course-search",
                options: FunctionInvokeOptions(
                    body: bodyData
                )
            )
        } catch {
            
            throw error
        }
        
        print("Decoded courses:", searchResponse.courses.map { $0.titleText })
        self.courses = searchResponse.courses
        return searchResponse.courses
    }

    // MARK: - /v1/courses/{id}
    func fetchCourse(id: String) async throws -> GolfCourse {
        let request = CourseIDRequest(courseId: id)
        let bodyData = try JSONEncoder().encode(request)
        
        let courseResponse: CourseResponse
        do {
            courseResponse = try await supabase.functions.invoke(
                "golf-course-search",
                options: FunctionInvokeOptions(
                    body:bodyData
                )
            )
        } catch {
            print("Fetch course failed:", error)
            throw error
        }
        return courseResponse.course
    }
    
}

