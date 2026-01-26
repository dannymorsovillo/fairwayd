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

@MainActor
final class ExploreService: ObservableObject {
    // MARK: - Published
    @Published var errorText = ""
    @Published var query = ""
    @Published var isSearching = false
    @Published var mode: ExploreMode = .explore
    @Published var topRatedCourses: [GolfCourse] = []
    @Published var topSlopeCourses: [GolfCourse] = []
    @Published var topBogeyCourses: [GolfCourse] = []
    @Published var hasLoadedCourses = false

    private var currentTask: Task<Void, Never>? = nil
    private var lastRefresh: Date? = nil
    private let courseCache = CourseCache()

    private let service: GolfCourseService
    private let finderService: GolfCourseFinderService
    private let locationManager: LocationManager
    private let store: EngagementStore

    init(
        service: GolfCourseService,
        finderService: GolfCourseFinderService,
        store: EngagementStore,
        locationManager: LocationManager
    ) {
        self.service = service
        self.finderService = finderService
        self.store = store
        self.locationManager = locationManager
    }

    func search() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Cancel previous task
        currentTask?.cancel()
        mode = .searching
        isSearching = true
        errorText = ""

        currentTask = Task { [weak self] in
            guard let self else { return }
            defer { Task { @MainActor in self.isSearching = false } }

            do {
                let courses = try await self.service.searchCourses(query: trimmed)

                // Nearby courses for enrichment
                let nearbyCourses: [GolfCourse]
                if let loc = self.locationManager.location, let cached = await self.courseCache.get(for: loc) {
                    nearbyCourses = cached
                } else if let loc = self.locationManager.location {
                    let clubs = try await self.finderService.fetchNearbyCourses(
                        latitude: loc.coordinate.latitude,
                        longitude: loc.coordinate.longitude,
                        miles: 50
                    )
                    nearbyCourses = self.finderService.mapNearbyClubsToGolfCourses(clubs)
                    await self.courseCache.set(nearbyCourses, for: loc)
                } else {
                    nearbyCourses = []
                }

                // Enrich courses concurrently
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
                    self.service.courses = enrichedCourses
                }
            } catch is CancellationError {
                print("Search task cancelled — ignoring")
            } catch {
                await MainActor.run {
                    self.errorText = error.localizedDescription
                }
            }
        }
    }

    func loadDefaultExploreIfNeeded(using location: CLLocation) {
        guard mode == .explore, !hasLoadedCourses else { return }
        loadDefaultExplore(using: location)
        hasLoadedCourses = true
    }

    func loadDefaultExplore(using location: CLLocation, forceReload: Bool = false) {
        // Prevent overlapping tasks
        currentTask?.cancel()
        currentTask = Task { [weak self] in
            guard let self else { return }

            if forceReload {
                if let last = self.lastRefresh, Date().timeIntervalSince(last) < 10 {
                    return
                }
                self.lastRefresh = Date()
            }

            self.errorText = ""

            // Cache fast-path
            if !forceReload, let cached = await self.courseCache.get(for: location) {
                self.topRatedCourses = Array(cached.sorted { ($0.bestCourseRating ?? 0) > ($1.bestCourseRating ?? 0) }.prefix(6))
                self.topSlopeCourses = Array(cached.sorted { ($0.bestSlopeRating ?? 0) > ($1.bestSlopeRating ?? 0) }.prefix(6))
                self.topBogeyCourses = Array(cached.sorted { ($0.bestBogeyRating ?? 0) > ($1.bestBogeyRating ?? 0) }.prefix(6))
                return
            }

            do {
                // Fetch nearby clubs
                let nearbyClubs = try await self.finderService.fetchNearbyCourses(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    miles: 50
                )
                let nearbyCourses = self.finderService.mapNearbyClubsToGolfCourses(nearbyClubs)
                await self.courseCache.set(nearbyCourses, for: location)

                // Search detailed courses concurrently
                let coursesToProcess = Array(nearbyCourses.prefix(50))
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
                    
                    for await result in group { if let course = result { results.append(course) } }
                    return results
                }

                // Enrich concurrently
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

                // Cache + Sort
                await self.courseCache.set(enrichedCourses, for: location)
                self.topRatedCourses = Array(enrichedCourses.sorted { ($0.bestCourseRating ?? 0) > ($1.bestCourseRating ?? 0) }.prefix(6))
                self.topSlopeCourses = Array(enrichedCourses.sorted { ($0.bestSlopeRating ?? 0) > ($1.bestSlopeRating ?? 0) }.prefix(6))
                self.topBogeyCourses = Array(enrichedCourses.sorted { ($0.bestBogeyRating ?? 0) > ($1.bestBogeyRating ?? 0) }.prefix(6))

            } catch is CancellationError {
                print("Explore load task cancelled — ignoring")
            } catch {
                print("Explore load failed:", error)
                self.errorText = "Failed to load courses: \(error.localizedDescription)"
            }
        }
    }
}

