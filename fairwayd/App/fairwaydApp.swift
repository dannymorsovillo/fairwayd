//
//  fairwaydApp.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 11/12/25.
//
import SwiftUI
import GoogleSignIn
import CoreML

@main
struct fairwaydApp: App {
    @StateObject private var session = SessionStore()
    @StateObject private var reviewService = ReviewService()
    @StateObject private var engagementStore = EngagementStore()
    @StateObject private var locationManager = LocationManager()
    
    @StateObject private var service = GolfCourseService()
    @StateObject private var finderService: GolfCourseFinderService
    @StateObject private var exploreService: ExploreService
    @StateObject private var recommendationService: RecommendationService
    
    init() {
        let locationMgr = LocationManager()
        let engageStore = EngagementStore()
        let golfService = GolfCourseService()
        let finder = GolfCourseFinderService(locationManager: locationMgr)
        
        _locationManager = StateObject(wrappedValue: locationMgr)
        _engagementStore = StateObject(wrappedValue: engageStore)
        _service = StateObject(wrappedValue: golfService)
        _finderService = StateObject(wrappedValue: finder)
        
        _exploreService = StateObject(wrappedValue: ExploreService(
            service: golfService,
            finderService: finder,
            store: engageStore,
            locationManager: locationMgr
        ))
        
        // Core ML model init: use configuration and handle failures gracefully
        let scorer: CourseScoring
        do {
            let config = MLModelConfiguration()
            // Optionally: config.computeUnits = .all / .cpuAndGPU / .cpuOnly
            let model = try fairwaydML(configuration: config)
            scorer = MLBasedCourseScorer(model: model)
        } catch {
            // Fallback to rules if model fails to load
            print("Failed to load fairwaydML model: \(error)")
            scorer = RuleBasedCourseScorer()
        }
        
        _recommendationService = StateObject(wrappedValue: RecommendationService(
            service: golfService,
            finderService: finder,
            store: engageStore,
            locationManager: locationMgr,
            scorer: scorer
        ))
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(reviewService)
                .environmentObject(locationManager)
                .environmentObject(engagementStore)
                .environmentObject(service)
                .environmentObject(finderService)
                .environmentObject(exploreService)
                .environmentObject(recommendationService)
                .task {
                    session.engagementStore = engagementStore
                }
                .onOpenURL(perform: { url in
                    GIDSignIn.sharedInstance.handle(url)
                })
        }
    }
}
