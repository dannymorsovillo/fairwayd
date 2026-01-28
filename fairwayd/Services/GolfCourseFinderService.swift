//
//  GolfCourseFinderService.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 1/5/26.
//

import Foundation
import Combine
import Supabase
import CoreLocation


struct NearbyCoursesRequest: Codable {
    let latitude: Double
    let longitude: Double
    let miles: Int
}

struct NearbyClub: Codable {
    let club_name: String
    let phone: String?
    let website: String?
    let golf_courses: [NearbyCourse]
}

struct NearbyCourse: Codable {
    let course_name: String
}


final class GolfCourseFinderService: ObservableObject {
    private let locationManager: LocationManager
    private let supabase = SupabaseManager.shared.client
    
    init(locationManager: LocationManager) {
        self.locationManager = locationManager
    }
    
    func fetchNearbyCourses(
        latitude: Double,
        longitude: Double,
        miles: Int = 50
    ) async throws -> [NearbyClub] {
        let request = NearbyCoursesRequest(
            latitude: latitude,
            longitude: longitude,
            miles: miles
        )
        
        let body = try JSONEncoder().encode(request)
        
        let clubs: [NearbyClub] = try await supabase.functions.invoke(
            "nearby-courses",
            options: FunctionInvokeOptions(body: body)
        )
        
        
        return clubs
    }
    
    func mapNearbyClubsToGolfCourses(_ clubs: [NearbyClub]) -> [GolfCourse] {
        var courses: [GolfCourse] = []
        
        for club in clubs {
            
            for course in club.golf_courses {
                let golfCourse = GolfCourse(
                    id: UUID().hashValue,
                    placeID: nil,
                    club_name: club.club_name,
                    course_name: course.course_name,
                    location: nil,
                    tees: nil,
                    city: nil,
                    state: nil,
                    phone: club.phone,
                    website: club.website
                )
                courses.append(golfCourse)
            }
        }
        return courses
    }
    
    func enrichCourseWContactInfo(
        _ course: GolfCourse,
        nearbyCourses: [GolfCourse]
    ) async -> GolfCourse {

        if let phone = course.phone, !phone.isEmpty,
           let website = course.website, !website.isEmpty {
            return course
        }

        if let match = nearbyCourses.first(where: {
            normalizeCourseName($0.titleText) == normalizeCourseName(course.titleText)
        }) {
            return GolfCourse(
                id: course.id,
                placeID: course.placeID,
                club_name: course.club_name,
                course_name: course.course_name,
                location: course.location,
                tees: course.tees,
                city: course.city,
                state: course.state,
                phone: match.phone,
                website: match.website
            )
        }

        return course
    }

}

