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
    ) async throws -> [NearbyCourse] {
        let request = NearbyCoursesRequest(
            latitude: latitude,
            longitude: longitude,
            miles: miles
        )

        let body = try JSONEncoder().encode(request)

        let courses: [NearbyCourse] = try await supabase.functions.invoke(
            "nearby-courses",
            options: FunctionInvokeOptions(body: body)
        )

        return courses
    }

    /// The nearby feed is flat — one row is one course, so the old
    /// club-to-course fan-out loop is gone.
    func mapNearbyClubsToGolfCourses(_ nearby: [NearbyCourse]) -> [GolfCourse] {
        nearby.map { course in
            GolfCourse(
                id: course.source_id,
                placeID: nil,
                club_name: course.name,
                course_name: course.name,
                location: Location(
                    address: course.address,
                    latitude: course.latitude,
                    longitude: course.longitude
                ),
                tees: nil,
                phone: course.phone,
                website: course.website
            )
        }
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
                phone: match.phone,
                website: match.website
            )
        }

        return course
    }

}
