//
//  MLExportDebugView.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 1/19/26.
//

import SwiftUI
import CoreLocation

struct MLExportDebugView: View {
    @EnvironmentObject private var golfCourseService: GolfCourseService
    @EnvironmentObject private var finderService: GolfCourseFinderService
    
    @State private var isExporting = false
    @State private var logText = "Ready to export ML training CSV"

    var body: some View {
        VStack(spacing: 12) {
            Text("Debug / Dev Tools")
                .font(.headline)
                .padding()
            
            Text(logText)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding()
            
            #if DEBUG
            Button(isExporting ? "Exporting..." : "Export ML Training CSV") {
                Task {
                    await exportMLTrainingCSV()
                }
            }
            .disabled(isExporting)
            #endif
        }
        .padding()
    }
    
    // MARK: - Export ML CSV
    @MainActor
    private func exportMLTrainingCSV() async {
        isExporting = true
        logText = "Fetching courses..."
        
        // 1️⃣ Define cities to sample
        let cities: [(name: String, state: String, lat: Double, lon: Double)] = [
            // West
            ("Los Angeles","CA",34.0522,-118.2437),
            ("San Francisco","CA",37.7749,-122.4194),
            ("Phoenix","AZ",33.4484,-112.0740),
            ("Denver","CO",39.7392,-104.9903),
            // Midwest
            ("Chicago","IL",41.8781,-87.6298),
            ("Minneapolis","MN",44.9778,-93.2650),
            ("Detroit","MI",42.3314,-83.0458),
            ("Kansas City","MO",39.0997,-94.5786),
            // South
            ("Dallas","TX",32.7767,-96.7970),
            ("Houston","TX",29.7604,-95.3698),
            ("Miami","FL",25.7617,-80.1918),
            ("Orlando","FL",28.5383,-81.3792),
            ("Atlanta","GA",33.7490,-84.3880),
            ("Charlotte","NC",35.2271,-80.8431),
            // Northeast
            ("New York","NY",40.7128,-74.0060),
            ("Boston","MA",42.3601,-71.0589),
            ("Philadelphia","PA",39.9526,-75.1652),
            ("Washington D.C.","DC",38.9072,-77.0369)
        ]
        
        var allMatchedCourses: [GolfCourse] = []
        
        // 2️⃣ Query each city for nearby courses
        for city in cities {
            do {
                let nearbyClubs = try await finderService.fetchNearbyCourses(
                    latitude: city.lat,
                    longitude: city.lon,
                    miles: 50
                )
                
                let coursesToProcess = nearbyClubs
                    .flatMap { club in
                        club.golf_courses.map { (clubName: club.club_name, courseName: $0.course_name) }
                    }
                    .prefix(20)
                
                let matchedCourses = await withTaskGroup(of: GolfCourse?.self) { group -> [GolfCourse] in
                    var results: [GolfCourse] = []
                    
                    for (index, course) in coursesToProcess.enumerated() {
                        group.addTask {
                            try? await Task.sleep(nanoseconds: UInt64(index) * 150_000_000) // 0.15s per course
                            do {
                                let searchResults = try await golfCourseService.searchCourses(query: course.courseName)
                                return searchResults.first { normalizeCourseName($0.titleText) == normalizeCourseName(course.courseName) }
                            } catch {
                                print("Search error for \(course.courseName):", error)
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
                
                allMatchedCourses.append(contentsOf: matchedCourses)
                
            } catch {
                print("Error fetching nearby courses for \(city.name):", error)
            }
        }
        
        let fileURL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("course_training.csv")
        
        do {
            try generateTrainingCSV(
                courses: allMatchedCourses,
                skillLevels: SkillLevel.allCases,
                fileURL: fileURL
            )
            logText = " CSV exported to: \(fileURL.path)"
            print("CSV exported:", fileURL)
        } catch {
            logText = " CSV export failed: \(error)"
            print("CSV export failed:", error)
        }
        
        isExporting = false
    }
    
    struct TrainingRow {
        let courseRating: Double
        let slope: Int
        let bogeyRating: Double
        let par: Int
        let handicap: Double
        let totalYards: Int
        let expectedScoreDiff: Double
    }

    private func generateTrainingCSV(
        courses: [GolfCourse],
        skillLevels: [SkillLevel],
        fileURL: URL
    ) throws {
        var rows: [TrainingRow] = []
        
        for course in courses {
            for tee in course.allTees {
                guard
                    let courseRating = tee.course_rating,
                    let slope = tee.slope_rating,
                    let bogeyRating = tee.bogey_rating,
                    let par = tee.par_total,
                    let totalYards = tee.total_yards
                else { continue }
                
                for skill in skillLevels {
                    let handicap = skill.estimatedHandiCap
                    let expectedScore = courseRating + (handicap * (Double(slope) / 113.0))
                    let diff = expectedScore - Double(par)
                    
                    rows.append(
                        TrainingRow(
                            courseRating: courseRating,
                            slope: slope,
                            bogeyRating: bogeyRating,
                            par: par,
                            handicap: handicap,
                            totalYards: totalYards,
                            expectedScoreDiff: diff
                        )
                    )
                }
            }
        }
        
        var csv = "course_rating,slope,bogey_rating,par,handicap,total_yards,expected_score_diff\n"
        for row in rows {
            csv += "\(row.courseRating),\(row.slope),\(row.bogeyRating),\(row.par),\(row.handicap),\(row.totalYards),\(row.expectedScoreDiff)\n"
        }
        
        try csv.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}

