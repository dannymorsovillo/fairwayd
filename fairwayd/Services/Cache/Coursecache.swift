//
//  Coursecache.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 1/14/26.
//

import Foundation
import CoreLocation

actor CourseCache {
    private var cache: [String: CachedData] = [:]
    
    struct CachedData {
        let courses: [GolfCourse]
        let timestamp: Date
        let location: CLLocation
    }
    
    func get(for location: CLLocation) -> [GolfCourse]? {
        let key = locationKey(location)
        
        guard let cached = cache[key] else { return nil }
        
        let age = Date().timeIntervalSince(cached.timestamp)
        guard age < 3600 else {
            cache.removeValue(forKey: key)
            return nil
        }
        
        let distance = location.distance(from: cached.location) / 1609.34
        guard distance < 5 else { return nil }
        
        return cached.courses
    }
    
    func set(_ courses: [GolfCourse], for location: CLLocation) {
        let key = locationKey(location)
        cache[key] = CachedData(
            courses: courses,
            timestamp: Date(),
            location: location
        )
    }
    
    func clear() {
        cache.removeAll()
    }
    
    func clearExpired() {
        let now = Date()
        cache = cache.filter { _, data in
            now.timeIntervalSince(data.timestamp) < 3600
        }
    }
    
    private func locationKey(_ location: CLLocation) -> String {
        let lat = (location.coordinate.latitude * 10).rounded() / 10
        let lon = (location.coordinate.longitude * 10).rounded() / 10
        return "\(lat),\(lon)"
    }
}
