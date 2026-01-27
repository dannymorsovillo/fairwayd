//
//  RecommendationService.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 12/30/25.
//

import Foundation
import CoreLocation
import Supabase
import Combine
import CoreML

// MARK: - SkillLevel Extension
extension SkillLevel {
    var estimatedHandiCap: Double {
        switch self {
        case .scratch: 0
        case .lowHandicap: 5 // center of 1-9
        case .midHandicap: 14 // center of 10-18
        case .highHandicap: 24 // center of 19+
        }
    }
}

// MARK: - Course Scoring
protocol CourseScoring {
    func score(course: GolfCourse, skillLevel: SkillLevel) -> Double
}

struct MLBasedCourseScorer: CourseScoring {
    let model: fairwaydML_2

    func score(course: GolfCourse, skillLevel: SkillLevel) -> Double {
        guard let tee = course.allTees.first,
              let courseRating = tee.course_rating,
              let slope = tee.slope_rating,
              let bogey_rating = tee.bogey_rating,
              let par = tee.par_total,
              let total_yards = tee.total_yards else {
            return 0.0
        }

        let input = fairwaydML_2Input(
            course_rating: courseRating,
            slope: Int64(slope),
            bogey_rating: bogey_rating,
            par: Int64(par),
            handicap: skillLevel.estimatedHandiCap,
            total_yards: Int64(total_yards)
        )

        guard let prediction = try? model.prediction(input: input) else { return 0.0 }
        return prediction.expected_score_diff
    }
}

struct RuleBasedCourseScorer: CourseScoring {
    func score(course: GolfCourse, skillLevel: SkillLevel) -> Double {
        guard let tee = course.allTees.max(by: { ($0.course_rating ?? 0) < ($1.course_rating ?? 0) }) else {
            return 0.0
        }

        guard let par = tee.par_total, let slopeInt = tee.slope_rating else { return 0.0 }

        let courseRating = course.bestCourseRating ?? 0.0
        let slope = Double(slopeInt)
        let handicap = skillLevel.estimatedHandiCap
        let expectedScore = courseRating + (handicap * (slope / 113.0))

        return abs(expectedScore - Double(par))
    }
}

// MARK: - RecommendationService
@MainActor
final class RecommendationService: ObservableObject {
    // MARK: Published
    @Published var errorText = ""
    @Published var recommendedCourses: [GolfCourse] = []

    // MARK: Private
    private var currentTask: Task<Void, Never>? = nil
    private let courseCache = CourseCache()

    private let service: GolfCourseService
    private let finderService: GolfCourseFinderService
    private let store: EngagementStore
    private let locationManager: LocationManager
    private let scorer: CourseScoring

    // MARK: Init
    init(
        service: GolfCourseService,
        finderService: GolfCourseFinderService,
        store: EngagementStore,
        locationManager: LocationManager,
        scorer: CourseScoring
    ) {
        self.service = service
        self.finderService = finderService
        self.store = store
        self.locationManager = locationManager
        self.scorer = scorer
    }

    // MARK: Load Recommended Courses
    func loadRecCourses(
        for skillLevel: SkillLevel,
        using location: CLLocation,
        forceReload: Bool = false
    ) {
        // Cancel previous task
        currentTask?.cancel()
        currentTask = Task { [weak self] in
            guard let self else { return }

            self.errorText = ""

            // Cache fast-path
            if !forceReload, let cached = await self.courseCache.get(for: location) {
                let scoredCourses = cached.map { course in
                    (course, self.scorer.score(course: course, skillLevel: skillLevel))
                }
                self.recommendedCourses = scoredCourses.sorted { $0.1 < $1.1 }.map { $0.0 }
                return
            }

            do {
                // Fetch nearby courses
                let nearbyClubs = try await self.finderService.fetchNearbyCourses(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    miles: 50
                )

                let nearbyCourses = self.finderService.mapNearbyClubsToGolfCourses(nearbyClubs)
                let coursesToProcess = Array(nearbyCourses.prefix(100))

                // Match courses concurrently
                let matchedCourses = await withTaskGroup(of: GolfCourse?.self) { group -> [GolfCourse] in
                    var results: [GolfCourse] = []

                    for (index, nearbyCourse) in coursesToProcess.enumerated() {
                        group.addTask {
                            try? await Task.sleep(nanoseconds: UInt64(index * 100_000_000))

                            do {
                                let searchResults = try await self.service.searchCourses(query: nearbyCourse.course_name ?? "")
                                let detailedCourse = searchResults.first(where: {
                                    normalizeCourseName($0.titleText) == normalizeCourseName(nearbyCourse.titleText)
                                })

                                guard let course = detailedCourse,
                                      let lat = course.location?.latitude,
                                      let lon = course.location?.longitude else { return nil }

                                let distanceMiles = location.distance(from: CLLocation(latitude: lat, longitude: lon)) / 1609.34
                                return distanceMiles <= 50 ? course : nil

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

                // Cache + Score
                await self.courseCache.set(enrichedCourses, for: location)
                let scoredCourses = enrichedCourses.map { course in
                    (course, self.scorer.score(course: course, skillLevel: skillLevel))
                }
                self.recommendedCourses = scoredCourses.sorted { $0.1 < $1.1 }.map { $0.0 }

            } catch is CancellationError {
                print("Recommendation load task cancelled — ignoring")
            } catch {
                self.errorText = "Failed to fetch nearby courses: \(error.localizedDescription)"
            }
        }
    }
}

