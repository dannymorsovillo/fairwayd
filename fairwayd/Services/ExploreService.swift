//
//  ExploreService.swift (refactored) for incremental loading + ui updates
//  fairwayd
//
//  Created by Danny Morsovillo
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
    @Published var hasLoadedCourses = false
    @Published var loadingProgress: Double = 0
    
    // Top courses - updated incrementally
    @Published var topRatedCourses: [GolfCourse] = []
    @Published var topSlopeCourses: [GolfCourse] = []
    @Published var topBogeyCourses: [GolfCourse] = []
    
    // Search results - updated incrementally
    @Published var searchResults: [GolfCourse] = []
    
    
    private var currentTask: Task<Void, Never>?
    private var lastRefresh: Date?
    private var allLoadedCourses: [GolfCourse] = []
    
    private let courseLoader: CourseLoader
    private let service: GolfCourseService
    private let locationManager: LocationManager
    
    
    init(courseLoader: CourseLoader, service: GolfCourseService, locationManager: LocationManager) {
        self.courseLoader = courseLoader
        self.service = service
        self.locationManager = locationManager
    }
    
    // convenience initializer matching original API
    convenience init(
        service: GolfCourseService,
        finderService: GolfCourseFinderService,
        store: EngagementStore,
        locationManager: LocationManager
    ) {
        let loader = CourseLoader(service: service, finderService: finderService)
        self.init(courseLoader: loader, service: service, locationManager: locationManager)
    }
    
    func search() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        currentTask?.cancel()
        mode = .searching
        isSearching = true
        errorText = ""
        searchResults = []
        
        currentTask = Task { [weak self] in
            guard let self else { return }
            
            do {
                _ = try await self.courseLoader.searchCoursesIncrementally(
                    query: trimmed,
                    location: self.locationManager.location,
                    onCourseReady: { [weak self] course in
                        guard let self else { return }
                        // Avoid duplicates
                        if !self.searchResults.contains(where: { $0.id == course.id }) {
                            self.searchResults.append(course)
                        }
                    }
                )
                
                // update the service.courses for compatibility
                self.service.courses = self.searchResults
                self.isSearching = false
                
            } catch is CancellationError {
                print("Search cancelled")
            } catch {
                self.errorText = error.localizedDescription
                self.isSearching = false
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
            
            // Throttle force reloads
            if forceReload {
                if let last = self.lastRefresh, Date().timeIntervalSince(last) < 10 {
                    return
                }
                self.lastRefresh = Date()
                self.allLoadedCourses = []
                self.clearTopCourses()
            }
            
            self.errorText = ""
            self.loadingProgress = 0
            
            do {
                _ = try await self.courseLoader.loadCoursesIncrementally(
                    location: location,
                    skillLevel: nil,
                    maxCourses: 40,
                    forceReload: forceReload,
                    onCourseReady: { [weak self] course in
                        self?.addCourseToTopLists(course)
                    },
                    onProgress: { [weak self] progress in
                        self?.loadingProgress = progress
                    }
                )
                
                self.loadingProgress = 1.0
                
            } catch is CancellationError {
                print("Explore load cancelled")
            } catch {
                self.errorText = "Failed to load courses: \(error.localizedDescription)"
            }
        }
    }
    
    
    func clearSearch() {
        query = ""
        searchResults = []
        service.courses = []
        isSearching = false
        errorText = ""
        mode = .explore
    }
    
    
    private func clearTopCourses() {
        topRatedCourses = []
        topSlopeCourses = []
        topBogeyCourses = []
    }
    
    private func addCourseToTopLists(_ course: GolfCourse) {
        // Avoid duplicates in our tracking array
        guard !allLoadedCourses.contains(where: { $0.id == course.id }) else { return }
        allLoadedCourses.append(course)
        
        updateTopList(
            list: &topRatedCourses,
            course: course,
            getValue: { $0.bestCourseRating ?? 0 },
            maxCount: 6
        )
        
        updateTopList(
            list: &topSlopeCourses,
            course: course,
            getValue: { Double($0.bestSlopeRating ?? 0) },
            maxCount: 6
        )
        
        updateTopList(
            list: &topBogeyCourses,
            course: course,
            getValue: { $0.bestBogeyRating ?? 0 },
            maxCount: 6
        )
    }
    
    private func updateTopList(
        list: inout [GolfCourse],
        course: GolfCourse,
        getValue: (GolfCourse) -> Double,
        maxCount: Int
    ) {
        let courseValue = getValue(course)
        
        guard courseValue > 0 else { return }
        
        let insertIndex = list.firstIndex { existing in
            getValue(existing) < courseValue
        } ?? list.count
        
        if insertIndex < maxCount {
            list.insert(course, at: insertIndex)
            
            // Trim to max count
            if list.count > maxCount {
                list.removeLast()
            }
        }
    }
}
