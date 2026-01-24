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

// extension of skillLevel
extension SkillLevel {
    var estimatedHandiCap: Double {
        switch self {
        case .scratch: 0
        case .lowHandicap: 7
        case .midHandicap: 18
        case .highHandicap: 32
        }
    }
}

//for drop in ML
protocol CourseScoring {
    func score(course: GolfCourse, skillLevel: SkillLevel) -> Double
}

struct MLBasedCourseScorer: CourseScoring {
    let model: fairwaydML
    func score(course: GolfCourse, skillLevel: SkillLevel) -> Double {
        guard let tee = course.allTees.first,
              let courseRating = tee.course_rating,
              let slope = tee.slope_rating,
              let bogey_rating = tee.bogey_rating,
              let par = tee.par_total,
              let total_yards = tee.total_yards else {
            return 0.0
        }
        
        let input = fairwaydMLInput(
            course_rating: courseRating,
            slope: Int64(slope),
            bogey_rating: bogey_rating,
            par: Int64(par),
            handicap: skillLevel.estimatedHandiCap,
            total_yards: Int64(total_yards)
        )
        
        guard let prediction = try? model.prediction(input: input) else {
            return 0
        }
        
        return prediction.expected_score_diff
    }
}


//fall back if models fails
struct RuleBasedCourseScorer: CourseScoring {
     func score(course: GolfCourse, skillLevel: SkillLevel) -> Double {
            guard let tee = course.allTees.max(by: { ($0.course_rating ?? 0) < ($1.course_rating ?? 0) }) else {
                return 0.0
            }
            
            guard
                let par = tee.par_total,
                let slopeInt = tee.slope_rating else {
                return 0.0
            }
            
            let courseRating = course.bestCourseRating ?? 0.0
            
            let slope = Double(slopeInt)
            let handicap = skillLevel.estimatedHandiCap
            let expectedScore = courseRating + (handicap * (slope / 113.0))
            
            return abs(expectedScore - Double(par))
        }
}

final class RecommendationService: ObservableObject{
    @Published var errorText = ""
    @Published var recommendedCourses: [GolfCourse] = []
    @Published var course: GolfCourse?
    @Published var tee: Tees?
    
    
    private let supabase = SupabaseManager.shared.client
    private let courseCache = CourseCache()
    
    private let service: GolfCourseService
    private let finderService: GolfCourseFinderService
    private let store: EngagementStore
    private let locationManager: LocationManager
    private let scorer: CourseScoring
    
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
    
    
    @MainActor
    func loadRecCourses(for skillLevel: SkillLevel, using location: CLLocation) async {

        errorText = ""

        // Cache
        if let cachedCourses = await courseCache.get(for: location) {
            let scoredCourses = cachedCourses.map { course -> (GolfCourse, Double) in
                let score = scorer.score(course: course, skillLevel: skillLevel)
                return (course, score)
            }

            let sortedCourses = scoredCourses.sorted { $0.1 < $1.1 }
            recommendedCourses = sortedCourses.map { $0.0 }
            return
        }

        do {
            // fetch nearby clubs once
            let nearbyClubs = try await finderService.fetchNearbyCourses(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                miles: 50
            )

            let nearbyCoursesWithContact = finderService.mapNearbyClubsToGolfCourses(nearbyClubs)
            let coursesToProcess = Array(nearbyCoursesWithContact.prefix(100))

            //  match courses
            let matchedCourses = await withTaskGroup(of: GolfCourse?.self) { group in
                var results: [GolfCourse] = []

                for (index, nearbyCourse) in coursesToProcess.enumerated() {
                    group.addTask {
                        try? await Task.sleep(nanoseconds: UInt64(index * 100_000_000))

                        do {
                            let searchResults = try await self.service.searchCourses(
                                query: nearbyCourse.course_name ?? ""
                            )

                            let detailedCourse = searchResults.first(where: {
                                normalizeCourseName($0.titleText) ==
                                normalizeCourseName(nearbyCourse.titleText)
                            })

                            guard let course = detailedCourse,
                                  let lat = course.location?.latitude,
                                  let lon = course.location?.longitude else {
                                return nil
                            }

                            let courseLocation = CLLocation(latitude: lat, longitude: lon)
                            let distanceMiles = location.distance(from: courseLocation) / 1609.34
                            guard distanceMiles <= 50 else { return nil }

                            return course
                        } catch {
                            print("Search error for \(nearbyCourse.titleText):", error)
                            return nil
                        }
                    }
                }

                for await result in group {
                    if let course = result {
                        results.append(course)
                    }
                }

                return results
            }

            let enrichedCourses = await withTaskGroup(of: GolfCourse.self) { group in
                var enriched: [GolfCourse] = []

                for course in matchedCourses {
                    group.addTask {
                        await self.finderService.enrichCourseWContactInfo(course, nearbyCourses: nearbyCoursesWithContact)
                    }
                }

                for await course in group {
                    enriched.append(course)
                }

                return enriched
            }


            // cache
            await courseCache.set(enrichedCourses, for: location)

            // score
            let scoredCourses = enrichedCourses.map { course -> (GolfCourse, Double) in
                let score = scorer.score(course: course, skillLevel: skillLevel)
                return (course, score)
            }

            // rank
            let sortedCourses = scoredCourses.sorted { $0.1 < $1.1 }
            recommendedCourses = sortedCourses.map { $0.0 }

        } catch {
            errorText = "Failed to fetch nearby courses: \(error.localizedDescription)"
        }
    }

}


        
    
