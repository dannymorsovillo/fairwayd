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


@MainActor
final class RecommendationService: ObservableObject {
    @Published var errorText = ""
    @Published var recommendedCourses: [GolfCourse] = []
    @Published var loadingProgress: Double = 0

    private var currentTask: Task<Void, Never>?
    private let courseCache = CourseCache()

    private let service: GolfCourseService
    private let finderService: GolfCourseFinderService
    private let store: EngagementStore
    private let locationManager: LocationManager
    private let scorer: CourseScoring

    private let batchConfig = BatchProcessor.Config.default

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

    func loadRecCourses(
        for skillLevel: SkillLevel,
        using location: CLLocation,
        forceReload: Bool = false
    ) {
        currentTask?.cancel()
        currentTask = Task { [weak self] in
            guard let self else { return }

            self.errorText = ""
            self.loadingProgress = 0

            if !forceReload, let cached = await self.courseCache.get(for: location) {
                self.recommendedCourses = self.scoreAndSort(cached, skillLevel: skillLevel)
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

                let enrichedCourses = await BatchProcessor.processParallel(
                    items: matchedCourses
                ) { course in
                    await self.finderService.enrichCourseWContactInfo(course, nearbyCourses: nearbyCourses)
                }

                await self.courseCache.set(enrichedCourses, for: location)
                self.recommendedCourses = self.scoreAndSort(enrichedCourses, skillLevel: skillLevel)
                self.loadingProgress = 1.0

            } catch is CancellationError {
                print("Recommendation task cancelled")
            } catch {
                self.errorText = "Failed to fetch courses: \(error.localizedDescription)"
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

    private func scoreAndSort(_ courses: [GolfCourse], skillLevel: SkillLevel) -> [GolfCourse] {
        courses
            .map { ($0, scorer.score(course: $0, skillLevel: skillLevel)) }
            .sorted { $0.1 < $1.1 }
            .map { $0.0 }
    }
}
