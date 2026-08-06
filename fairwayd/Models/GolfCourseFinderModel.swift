//
//  GolfCourseFinderModel.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 8/6/26.
//

import Foundation
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
    let source_id: String
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
}
