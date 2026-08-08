//
//  fairwaydApp.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 11/12/25.
//
import SwiftUI
import UIKit
import GoogleSignIn
import CoreML

@main
struct fairwaydApp: App {
    @StateObject private var session = SessionStore()
    @StateObject private var reviewService = ReviewService()
    @StateObject private var engagementStore = EngagementStore()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var chatService = ChatService()
    @StateObject private var service = GolfCourseService()
    
    @StateObject private var finderService: GolfCourseFinderService
    @StateObject private var exploreService: ExploreService
    @StateObject private var recommendationService: RecommendationService
    
    @MainActor
    init() {
        let locationMgr = LocationManager()
        let engageStore = EngagementStore()
        let golfService = GolfCourseService()
        let finder = GolfCourseFinderService(locationManager: locationMgr)
        let courseLoader = CourseLoader(service: golfService, finderService: finder)
        
        _locationManager = StateObject(wrappedValue: locationMgr)
        _engagementStore = StateObject(wrappedValue: engageStore)
        _service = StateObject(wrappedValue: golfService)
        _finderService = StateObject(wrappedValue: finder)
        
        _exploreService = StateObject(wrappedValue: ExploreService(
            courseLoader: courseLoader,
            service: golfService,
            locationManager: locationMgr
        ))
        
        
        let scorer: CourseScoring
        do {
            let config = MLModelConfiguration()
            let model = try fairwaydML_2(configuration: config)
            scorer = MLBasedCourseScorer(model: model)
        } catch {
            // Fallback to rules if model fails to load
            print("Failed to load fairwaydML model: \(error)")
            scorer = RuleBasedCourseScorer()
        }
        
        _recommendationService = StateObject(wrappedValue: RecommendationService(
            courseLoader: courseLoader,
            scorer: scorer
        ))
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                //#if DEBUG
                // MLExportDebugView()
                //#else
                //LocalNotifications()
                RootView()
                //#endif
            }
            .environmentObject(session)
            .environmentObject(reviewService)
            .environmentObject(locationManager)
            .environmentObject(engagementStore)
            .environmentObject(service)
            .environmentObject(finderService)
            .environmentObject(exploreService)
            .environmentObject(recommendationService)
            .environmentObject(chatService)
            .task {
                session.engagementStore = engagementStore
            }
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
        }
    }
}
