//
//  ExploreService.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 1/23/26.
//

import Foundation
import Combine
import CoreLocation

enum ExploreMode {
    case explore
    case searching
}

final class ExploreService: ObservableObject {
    @Published var errorText = ""
    @Published var query = ""
    @Published var isSearching = false
    @Published var mode: ExploreMode = .explore
    @Published var topRatedCourses: [GolfCourse] = []
    @Published var topSlopeCourses: [GolfCourse] = []
    @Published var topBogeyCourses: [GolfCourse] = []
    @Published var hasLoadedCourses = false
    
    private var exploreTask: Task<Void, Never>?
    private let courseCache = CourseCache()
    private let matchedCourses: [GolfCourse] = []
    
    private let service: GolfCourseService
    private let finderService: GolfCourseFinderService
    private let locationManager: LocationManager
    private let store: EngagementStore
    
    init(
        service: GolfCourseService,
        finderService: GolfCourseFinderService,
        store: EngagementStore,
        locationManager: LocationManager,
    ) {
        self.service = service
        self.finderService = finderService
        self.store = store
        self.locationManager = locationManager
    }
    
    @MainActor
    func search() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        exploreTask?.cancel()
        mode = .searching
        isSearching = true
        errorText = ""

        exploreTask = Task {
            defer { Task { @MainActor in isSearching = false } }

            do {
                let courses = try await service.searchCourses(query: trimmed)

                // ---------- Nearby courses (for enrichment) ----------
                let nearbyCourses: [GolfCourse]
                if let loc = locationManager.location, let cached = await courseCache.get(for: loc) {
                    nearbyCourses = cached
                } else if let loc = locationManager.location {
                    let clubs = try await finderService.fetchNearbyCourses(
                        latitude: loc.coordinate.latitude,
                        longitude: loc.coordinate.longitude,
                        miles: 50
                    )
                    nearbyCourses = finderService.mapNearbyClubsToGolfCourses(clubs)
                    await courseCache.set(nearbyCourses, for: loc)
                } else {
                    nearbyCourses = []
                }

                // ---------- Enrich ----------
                let enrichedCourses = await withTaskGroup(of: GolfCourse.self) { group -> [GolfCourse] in
                    var enriched: [GolfCourse] = []
                    for course in courses {
                        group.addTask {
                            await self.finderService.enrichCourseWContactInfo(course, nearbyCourses: nearbyCourses)
                        }
                    }
                    for await course in group { enriched.append(course) }
                    return enriched
                }

                await MainActor.run {
                    service.courses = enrichedCourses
                }

            } catch {
                await MainActor.run {
                    errorText = error.localizedDescription
                }
            }
        }
    }

    @MainActor
    func loadDefaultExploreIfNeeded(using location: CLLocation) async {
        guard mode == .explore, !hasLoadedCourses else { return }
        
        exploreTask?.cancel()
        exploreTask = Task {
            await loadDefaultExplore(using: location)
                hasLoadedCourses = true
            }
    }

    
    @MainActor
    func loadDefaultExplore(using location: CLLocation) async {
        errorText = ""

        // ---------- 1. Cache fast-path ----------
        if let cachedCourses = await courseCache.get(for: location) {
            topRatedCourses = Array(cachedCourses.sorted { ($0.bestCourseRating ?? 0) > ($1.bestCourseRating ?? 0) }.prefix(6))
            topSlopeCourses = Array(cachedCourses.sorted { ($0.bestSlopeRating ?? 0) > ($1.bestSlopeRating ?? 0) }.prefix(6))
            topBogeyCourses = Array(cachedCourses.sorted { ($0.bestBogeyRating ?? 0) > ($1.bestBogeyRating ?? 0) }.prefix(6))
            return
        }

        do {
            // ---------- 2. Fetch nearby courses ----------
            let nearbyClubs = try await finderService.fetchNearbyCourses(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                miles: 50
            )
            let nearbyCourses = finderService.mapNearbyClubsToGolfCourses(nearbyClubs)
            await courseCache.set(nearbyCourses, for: location)

            // ---------- 3. Search detailed courses ----------
            let coursesToProcess = Array(nearbyCourses.prefix(100))
            let matchedCourses = await withTaskGroup(of: GolfCourse?.self) { group -> [GolfCourse] in
                var results: [GolfCourse] = []

                for (index, nearbyCourse) in coursesToProcess.enumerated() {
                    group.addTask {
                        try? await Task.sleep(nanoseconds: UInt64(index * 100_000_000))
                        do {
                            let searchResults = try await self.service.searchCourses(query: nearbyCourse.course_name ?? "")
                            return searchResults.first(where: {
                                guard let lat = $0.location?.latitude, let lon = $0.location?.longitude else { return false }
                                let distance = location.distance(from: CLLocation(latitude: lat, longitude: lon)) / 1609.34
                                return distance <= 50 && normalizeCourseName($0.titleText) == normalizeCourseName(nearbyCourse.titleText)
                            })
                        } catch {
                            print("Search error for \(nearbyCourse.titleText):", error)
                            return nil
                        }
                    }
                }

                for await result in group {
                    if let course = result { results.append(course) }
                }

                return results
            }

            // ---------- 4. Enrich ----------
            let enrichedCourses = await withTaskGroup(of: GolfCourse.self) { group -> [GolfCourse] in
                var enriched: [GolfCourse] = []
                for course in matchedCourses {
                    group.addTask {
                        await self.finderService.enrichCourseWContactInfo(course, nearbyCourses: nearbyCourses)
                    }
                }
                for await course in group { enriched.append(course) }
                return enriched
            }

            // ---------- 5. Cache + Sort ----------
            await courseCache.set(enrichedCourses, for: location)

            topRatedCourses = Array(enrichedCourses.sorted { ($0.bestCourseRating ?? 0) > ($1.bestCourseRating ?? 0) }.prefix(6))
            topSlopeCourses = Array(enrichedCourses.sorted { ($0.bestSlopeRating ?? 0) > ($1.bestSlopeRating ?? 0) }.prefix(6))
            topBogeyCourses = Array(enrichedCourses.sorted { ($0.bestBogeyRating ?? 0) > ($1.bestBogeyRating ?? 0) }.prefix(6))

        } catch {
            print("Explore load failed:", error)
            errorText = "Failed to load courses: \(error.localizedDescription)"
        }
    }
}
