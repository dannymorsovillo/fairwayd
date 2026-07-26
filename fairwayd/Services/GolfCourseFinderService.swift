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

/// One course as returned by the `nearby-courses` edge function.
///
/// Field names must match the edge function's output exactly. Everything except
/// `name` is optional — the upstream provider is inconsistent about what it
/// populates, and a non-optional field here throws a decoding error that blanks
/// the whole screen.
struct NearbyCourse: Codable {
    /// Upstream UUID string. Named `source_id` to match the edge function, and
    /// deliberately not `id` so it can't be confused with `GolfCourse.id`,
    /// which is an Int from golfcourseapi.
    let source_id: String?
    let name: String
    let distance_km: Double?
    let latitude: Double?
    let longitude: Double?
    /// Derived from `par` in the edge function. The upstream `holes` field
    /// counts scorecard rows it happens to have, not real holes.
    let holes: Int?
    let par: Int?
    let total_yardage: Int?
    let phone: String?
    let website: String?
    let address: String?

    var coordinate: CLLocation? {
        guard let latitude, let longitude else { return nil }
        return CLLocation(latitude: latitude, longitude: longitude)
    }

    /// Deterministic ID for courses that exist only in the nearby feed.
    ///
    /// FNV-1a rather than `hashValue`: Swift seeds `hashValue` per process, so
    /// the same course would get a different ID on every launch, breaking
    /// `$0.id == course.id` dedupe checks and favorites lookups.
    var stableID: Int {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in (source_id ?? name).utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100_0000_01b3
        }
        return Int(bitPattern: UInt(hash & 0x7FFF_FFFF_FFFF_FFFF))
    }
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
                id: course.stableID,
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
