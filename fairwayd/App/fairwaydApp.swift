//
//  fairwaydApp.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 11/12/25.
//
import SwiftUI
import GoogleSignIn

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
        
            let model = try! fairwaydML()
            let scorer = MLBasedCourseScorer(model: model)
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
           // #if DEBUG
           // MLExportDebugView()
          //  #else
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
                }
                )
           // #endif
        }
    }
}
