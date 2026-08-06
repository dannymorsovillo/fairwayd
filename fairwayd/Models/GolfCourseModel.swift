//
//  GolfCourse.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 12/17/25.
//
import Foundation
import CoreLocation


struct SearchRequest: Codable {
    let query: String
}

struct CourseIDRequest: Codable {
    let courseId: String
}

struct SearchResponse: Codable {
    let courses: [GolfCourse]
}

struct CourseResponse: Codable {
    let course: GolfCourse
}

struct GolfCourse: Codable, Identifiable{
    let id: String
    let placeID: String?
    let club_name: String?
    let course_name: String?
    let location: Location?
    let tees: Tees?
    let phone: String?
    let website: String?
}

struct Location: Codable {
    let address: String?
    let city: String?
    let state: String?
    let country: String?
    let latitude: Double?
    let longitude: Double?
}

extension Location {
    /// For feeds that supply a position and a single address string but no
    /// city/state breakdown — e.g. the nearby-courses endpoint.
    init(address: String?, latitude: Double?, longitude: Double?) {
        self.init(
            address: address,
            city: nil,
            state: nil,
            country: nil,
            latitude: latitude,
            
            longitude: longitude
        )
    }
}

struct Tees: Codable {
    let female: [Tee]?
    let male: [Tee]?
}

struct Tee: Codable, Identifiable {
    let tee_name: String?
    let course_rating: Double?
    let slope_rating: Int?
    let bogey_rating: Double?
    let total_yards: Int?
    let total_meters: Int?
    let number_of_holes: Int?
    let par_total: Int?

    let front_course_rating: Double?
    let front_slope_rating: Int?
    let front_bogey_rating: Double?

    let back_course_rating: Double?
    let back_slope_rating: Int?
    let back_bogey_rating: Double?

    let holes: [Hole]?

    // Computed id (NOT decoded) so Codable works
    var id: String {
        "\(tee_name ?? "tee")-\(total_yards ?? 0)-\(par_total ?? 0)"
    }
}

struct Hole: Codable, Identifiable {
    let par: Int?
    let yardage: Int?
    let handicap: Int?

    var id: String {
        "\(par ?? 0)-\(yardage ?? 0)-\(handicap ?? 0)"
    }
}


extension GolfCourse {
    nonisolated var titleText: String { course_name ?? club_name ?? "Unknown Course" }

    var subtitleText: String {
        let city = location?.city ?? ""
        let state = location?.state ?? ""
        let combo = [city, state].filter { !$0.isEmpty }.joined(separator: ", ")
        return combo.isEmpty ? (location?.country ?? "Unknown Location") : combo
    }

    /// Nil when either coordinate is missing — several providers populate only
    /// an address string.
    var coordinate: CLLocation? {
        guard let latitude = location?.latitude,
              let longitude = location?.longitude else { return nil }
        return CLLocation(latitude: latitude, longitude: longitude)
    }

    var allTees: [Tee] { (tees?.male ?? []) + (tees?.female ?? []) }

    var bestCourseRating: Double? {
        allTees.compactMap { $0.course_rating }.max()
    }
    
    var bestSlopeRating: Int? {
            allTees.compactMap { $0.slope_rating }.max()
        }

    var bestBogeyRating: Double? {
            allTees.compactMap { $0.bogey_rating }.max()
    }
}

