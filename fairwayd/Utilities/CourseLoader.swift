//
//  CourseLoader.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 1/27/26.
//

import Foundation
import CoreLocation

actor ConcurrencyLimiter {
    private let maxConcurrent: Int
    private var currentCount = 0
    
    // can change as needed
    init(maxConcurrent: Int = 6) {
        self.maxConcurrent = maxConcurrent
    }
    
    func acquire() async {
        while currentCount >= maxConcurrent {
            await Task.yield()
        }
        currentCount += 1
    }
    
    func release() {
        currentCount = max(0, currentCount - 1)
    }
}

@MainActor
final class CourseLoader {
    
    private let service: GolfCourseService
    private let finderService: GolfCourseFinderService
    private let courseCache: CourseCache
    private let limiter = ConcurrencyLimiter(maxConcurrent: 6)
    
    init(
        service: GolfCourseService,
        finderService: GolfCourseFinderService,
        courseCache: CourseCache = CourseCache()
    ) {
        self.service = service
        self.finderService = finderService
        self.courseCache = courseCache
    }
    
    func loadCoursesIncrementally(
        location: CLLocation,
        skillLevel: SkillLevel?,
        maxCourses: Int = 40,
        forceReload: Bool = false,
        onCourseReady: @escaping (GolfCourse) -> Void,
        onProgress: ((Double) -> Void)? = nil
    ) async throws -> [GolfCourse] {
        
        // Check cache first
        if !forceReload, let cached = await courseCache.get(for: location, skillLevel: skillLevel) {
            for course in cached {
                onCourseReady(course)
            }
            onProgress?(1.0)
            return cached
        }
        
        // Fetch nearby courses from finder service
        let nearbyClubs = try await finderService.fetchNearbyCourses(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            miles: 50
        )
        
        let nearbyCourses = finderService.mapNearbyClubsToGolfCourses(nearbyClubs)
        let coursesToProcess = Array(nearbyCourses.prefix(maxCourses))
        
        guard !coursesToProcess.isEmpty else {
            onProgress?(1.0)
            return []
        }
        
        // Process courses concurrently with controlled parallelism
        var matchedCourses: [GolfCourse] = []
        var completedCount = 0
        let total = coursesToProcess.count
        
        try await withThrowingTaskGroup(of: GolfCourse?.self) { group in
            for course in coursesToProcess {
                group.addTask {
                    try Task.checkCancellation()
                    
                    await self.limiter.acquire()
                    defer { Task { await self.limiter.release() } }
                    
                    // Match course via search API
                    guard let matched = await self.matchCourse(course, location: location) else {
                        return nil
                    }
                    
                    // Enrich with contact info
                    let enriched = await self.finderService.enrichCourseWContactInfo(
                        matched,
                        nearbyCourses: nearbyCourses
                    )
                    
                    return enriched
                }
            }
            
            // Stream results as they complete
            for try await result in group {
                completedCount += 1
                let progress = Double(completedCount) / Double(total)
                onProgress?(progress)
                
                if let course = result {
                    matchedCourses.append(course)
                    onCourseReady(course)
                }
            }
        }
        
        // Cache the results
        await courseCache.set(matchedCourses, for: location, skillLevel: skillLevel)
        
        return matchedCourses
    }
    
    func searchCoursesIncrementally(
        query: String,
        location: CLLocation?,
        onCourseReady: @escaping (GolfCourse) -> Void
    ) async throws -> [GolfCourse] {
        
        let results = try await service.searchCourses(query: query)
        
        // Get nearby courses for enrichment (use cache if available)
        var nearbyCourses: [GolfCourse] = []
        
        if let location = location {
            if let cached = await courseCache.get(for: location) {
                nearbyCourses = cached
            } else {
                do {
                    let clubs = try await finderService.fetchNearbyCourses(
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude,
                        miles: 50
                    )
                    
                    nearbyCourses = finderService.mapNearbyClubsToGolfCourses(clubs)
                } catch {
                    print("Failed to map nearby clubs to courses", error)
                    throw error
                }
            }
        }
        
        // Enrich and stream results
        var enrichedResults: [GolfCourse] = []
        
        await withTaskGroup(of: GolfCourse.self) { group in
            for course in results {
                group.addTask {
                    await self.finderService.enrichCourseWContactInfo(
                        course,
                        nearbyCourses: nearbyCourses
                    )
                }
            }
            
            for await enriched in group {
                enrichedResults.append(enriched)
                onCourseReady(enriched)
            }
        }
        
        return enrichedResults
    }
    
    
    /// How close two providers' coordinates must be to be considered the same
    /// course. Resorts cluster tightly — Spyglass Hill sits ~1.6km from The Hay
    /// at Pebble Beach — so this is deliberately near the low end.
    private static let coordinateMatchMetres: CLLocationDistance = 2_000

    private func matchCourse(_ course: GolfCourse, location: CLLocation) async -> GolfCourse? {
        do {
            let results = try await service.searchCourses(query: course.course_name ?? "")
            let target = normalizeCourseName(course.titleText)

            // Name is the only signal available across both providers:
            // golfcourseapi returns an address but no coordinates, so a distance
            // test against a search result rejects everything.
            let matches = results.filter { normalizeCourseName($0.titleText) == target }
            guard !matches.isEmpty else { return nil }

            // A name query can return several courses that share a name in
            // different states ("Pine Ridge Country Club" ×4). Prefer the closest
            // when coordinates exist on both sides; otherwise take the first.
            if let origin = course.coordinate {
                let nearest = matches
                    .compactMap { candidate -> (course: GolfCourse, metres: CLLocationDistance)? in
                        guard let candidateLocation = candidate.coordinate else { return nil }
                        let metres = origin.distance(from: candidateLocation)
                        return metres <= Self.coordinateMatchMetres ? (candidate, metres) : nil
                    }
                    .min { $0.metres < $1.metres }

                if let nearest {
                    return nearest.course
                }
            }

            return matches.first
        } catch {
            return nil
        }
    }
}
