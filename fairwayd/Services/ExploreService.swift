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
    @Published var errorText = ""
    @Published var query = ""
    @Published var isSearching = false
    @Published var mode: ExploreMode = .explore
    @Published var topRatedCourses: [GolfCourse] = []
    @Published var topSlopeCourses: [GolfCourse] = []
    @Published var topBogeyCourses: [GolfCourse] = []
    @Published var hasLoadedCourses = false
    @Published var loadingProgress: Double = 0

    private var currentTask: Task<Void, Never>?
    private var lastRefresh: Date?
    private let courseCache = CourseCache()

    private let service: GolfCourseService
    private let finderService: GolfCourseFinderService
    private let locationManager: LocationManager
    private let store: EngagementStore

    private let batchConfig = BatchProcessor.Config.default

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

        currentTask?.cancel()
        mode = .searching
        isSearching = true
        errorText = ""

        currentTask = Task { [weak self] in
            guard let self else { return }
            defer { self.isSearching = false }

            do {
                let courses = try await self.service.searchCourses(query: trimmed)
                let nearbyCourses = await self.getOrFetchNearbyCourses()

                let enrichedCourses = await BatchProcessor.processParallel(items: courses) { course in
                    await self.finderService.enrichCourseWContactInfo(course, nearbyCourses: nearbyCourses)
                }

                self.service.courses = enrichedCourses

            } catch is CancellationError {
                print("Search cancelled")
            } catch {
                self.errorText = error.localizedDescription
            }
        }
    }

    func loadDefaultExploreIfNeeded(using location: CLLocation) {
        guard mode == .explore, !hasLoadedCourses else { return }
        loadDefaultExplore(using: location)
        hasLoadedCourses = true
    }

    func loadDefaultExplore(using location: CLLocation, forceReload: Bool = false) {
        currentTask?.cancel()
        currentTask = Task { [weak self] in
            guard let self else { return }

            if forceReload {
                if let last = self.lastRefresh, Date().timeIntervalSince(last) < 10 { return }
                self.lastRefresh = Date()
            }

            self.errorText = ""
            self.loadingProgress = 0

            if !forceReload, let cached = await self.courseCache.get(for: location) {
                self.updateTopCourses(from: cached)
                self.loadingProgress = 1.0
                return
            }

            do {
                let nearbyClubs = try await self.finderService.fetchNearbyCourses(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    miles: 50
                )
                let nearbyCourses = self.finderService.mapNearbyClubsToGolfCourses(nearbyClubs)

                let coursesToProcess = Array(nearbyCourses.prefix(50))

                let matchedCourses = try await BatchProcessor.process(
                    items: coursesToProcess,
                    config: self.batchConfig,
                    onProgress: { self.loadingProgress = $0 * 0.8 }
                ) { course in
                    await self.matchCourse(course, location: location)
                }

                let enrichedCourses = await BatchProcessor.processParallel(items: matchedCourses) { course in
                    await self.finderService.enrichCourseWContactInfo(course, nearbyCourses: nearbyCourses)
                }

                await self.courseCache.set(enrichedCourses, for: location)
                self.updateTopCourses(from: enrichedCourses)
                self.loadingProgress = 1.0

            } catch is CancellationError {
                print("Explore load cancelled")
            } catch {
                self.errorText = "Failed to load courses: \(error.localizedDescription)"
            }
        }
    }

    private func matchCourse(_ course: GolfCourse, location: CLLocation) async -> GolfCourse? {
        do {
            let results = try await service.searchCourses(query: course.course_name ?? "")
            return results.first {
                guard let lat = $0.location?.latitude, let lon = $0.location?.longitude else { return false }
                let distance = location.distance(from: CLLocation(latitude: lat, longitude: lon)) / 1609.34
                return distance <= 50 && normalizeCourseName($0.titleText) == normalizeCourseName(course.titleText)
            }
        } catch {
            return nil
        }
    }

    private func getOrFetchNearbyCourses() async -> [GolfCourse] {
        guard let location = locationManager.location else { return [] }

        if let cached = await courseCache.get(for: location) {
            return cached
        }

        do {
            let clubs = try await finderService.fetchNearbyCourses(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                miles: 50
            )
            let courses = finderService.mapNearbyClubsToGolfCourses(clubs)
            await courseCache.set(courses, for: location)
            return courses
        } catch {
            return []
        }
    }

    private func updateTopCourses(from courses: [GolfCourse]) {
        topRatedCourses = Array(courses.sorted { ($0.bestCourseRating ?? 0) > ($1.bestCourseRating ?? 0) }.prefix(6))
        topSlopeCourses = Array(courses.sorted { ($0.bestSlopeRating ?? 0) > ($1.bestSlopeRating ?? 0) }.prefix(6))
        topBogeyCourses = Array(courses.sorted { ($0.bestBogeyRating ?? 0) > ($1.bestBogeyRating ?? 0) }.prefix(6))
    }
}
