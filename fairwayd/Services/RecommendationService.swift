//
//  RecommendationService.swift (refactored) for incremental loading + ui updates
//  fairwayd
//
//  Created by Danny Morsovillo
//

import Foundation
import CoreLocation
import Combine
import CoreML

extension SkillLevel {
    var estimatedHandiCap: Double {
        switch self {
        case .scratch: 0
        case .lowHandicap: 5
        case .midHandicap: 14
        case .highHandicap: 24
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
            return Double.greatestFiniteMagnitude
        }

        let input = fairwaydML_2Input(
            course_rating: courseRating,
            slope: Int64(slope),
            bogey_rating: bogey_rating,
            par: Int64(par),
            handicap: skillLevel.estimatedHandiCap,
            total_yards: Int64(total_yards)
        )

        guard let prediction = try? model.prediction(input: input) else {
            return Double.greatestFiniteMagnitude
        }
        return prediction.expected_score_diff
    }
}

struct RuleBasedCourseScorer: CourseScoring {
    func score(course: GolfCourse, skillLevel: SkillLevel) -> Double {
        guard let tee = course.allTees.max(by: { ($0.course_rating ?? 0) < ($1.course_rating ?? 0) }),
              let par = tee.par_total,
              let slopeInt = tee.slope_rating else {
            return Double.greatestFiniteMagnitude
        }

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
    @Published var isLoading = false
    @Published var hasLoadedOnce = false
    
    private var currentTask: Task<Void, Never>?
    private let courseLoader: CourseLoader
    private let scorer: CourseScoring
    private var currentSkillLevel: SkillLevel?
    
    init(courseLoader: CourseLoader, scorer: CourseScoring) {
        self.courseLoader = courseLoader
        self.scorer = scorer
    }
    
    convenience init(
        service: GolfCourseService,
        finderService: GolfCourseFinderService,
        store: EngagementStore,
        locationManager: LocationManager,
        scorer: CourseScoring
    ) {
        let loader = CourseLoader(service: service, finderService: finderService)
        self.init(courseLoader: loader, scorer: scorer)
    }
    
    func loadRecCourses(
        for skillLevel: SkillLevel,
        using location: CLLocation,
        forceReload: Bool = false
    ) {
        let skillLevelChanged = currentSkillLevel != nil && currentSkillLevel != skillLevel

        if hasLoadedOnce && !forceReload && !skillLevelChanged {
            return
        }
        
        currentTask?.cancel()
        currentSkillLevel = skillLevel
        
        currentTask = Task { [weak self] in
            guard let self else { return }
            
            self.errorText = ""
            self.loadingProgress = 0
            self.isLoading = true
            
            if forceReload || skillLevelChanged {
                self.recommendedCourses = []
            }
            
            do {
                var allCourses: [GolfCourse] = []
                
                _ = try await self.courseLoader.loadCoursesIncrementally(
                    location: location,
                    skillLevel: skillLevel,
                    maxCourses: 100,
                    forceReload: forceReload || skillLevelChanged,
                    onCourseReady: { course in
                        allCourses.append(course)
                    },
                    onProgress: { [weak self] progress in
                        self?.loadingProgress = progress
                    }
                )
                
                // Sort using combined score (ML + difficulty penalty)
                let sorted = allCourses.sorted {
                    self.combinedScore(course: $0, skillLevel: skillLevel) < self.combinedScore(course: $1, skillLevel: skillLevel)
                }
                    
                self.recommendedCourses = Array(sorted.prefix(40))
                
                self.isLoading = false
                self.hasLoadedOnce = true
                self.loadingProgress = 1.0
                
            } catch is CancellationError {
                print("Recommendation task cancelled")
            } catch {
                self.errorText = "Failed to fetch courses: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    
    private func combinedScore(course: GolfCourse, skillLevel: SkillLevel) -> Double {
        let mlScore = scorer.score(course: course, skillLevel: skillLevel)
        let penalty = difficultyPenalty(course: course, skillLevel: skillLevel)
        
        return mlScore + penalty
    }
    
    private func difficultyPenalty(course: GolfCourse, skillLevel: SkillLevel) -> Double {
        guard let slope = course.bestSlopeRating else { return 10.0 }
        
        // Derived from training data: avg slope where score_diff is in ideal range
        let ideal: Double = switch skillLevel {
        case .scratch:     129  // score_diff 0 to +4
        case .lowHandicap: 126  // score_diff +4 to +8
        case .midHandicap: 120  // score_diff +10 to +16
        case .highHandicap: 117 // score_diff +18 to +26
        }
        
        let diff = abs(Double(slope) - ideal)
        return diff * 0.3
    }
    
}
