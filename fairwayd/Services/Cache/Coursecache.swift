//
//  CourseCache.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 1/14/26.
//

import Foundation
import CoreLocation

actor CourseCache {
    private var cache: [String: CachedData] = [:]
    
    func get(for location: CLLocation, skillLevel: SkillLevel? = nil) -> [GolfCourse]? {
        let key = cacheKey(location: location, skillLevel: skillLevel)
        
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
    
    func set(_ courses: [GolfCourse], for location: CLLocation, skillLevel: SkillLevel? = nil) {
        let key = cacheKey(location: location, skillLevel: skillLevel)
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
    
    func clear(for skillLevel: SkillLevel) {
        cache = cache.filter { key, _ in
            !key.hasSuffix(":\(skillLevel.rawValue)")
        }
    }
    
    private func cacheKey(location: CLLocation, skillLevel: SkillLevel?) -> String {
        let lat = (location.coordinate.latitude * 10).rounded() / 10
        let lon = (location.coordinate.longitude * 10).rounded() / 10
        let locationPart = "\(lat),\(lon)"
        
        if let skillLevel = skillLevel {
            return "\(locationPart):\(skillLevel.rawValue)"
        }
        return locationPart
    }
}
