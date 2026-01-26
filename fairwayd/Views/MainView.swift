//
//  RootTabView.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 12/17/25.
//
import SwiftUI


struct MainView: View {
    @EnvironmentObject var store: EngagementStore
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var service: GolfCourseService  //GolfCourse API
    @EnvironmentObject var finderService: GolfCourseFinderService //Rapid API
    @EnvironmentObject var exploreService: ExploreService
    @EnvironmentObject var recommendationService: RecommendationService
    
    
    var body: some View {
        TabView {
            NavigationStack {
                ExploreView()
                .environmentObject(store)
            }
            .tabItem { Label("Explore", systemImage: "magnifyingglass") }

            NavigationStack {
                RecommendationsView()
                .environmentObject(store)
            }
            .tabItem { Label("For You", systemImage: "sparkles") }
            
            NavigationStack {
                LeaveReviewTabView()
            }
            .tabItem{ Label("Leave a Review", systemImage: "plus")}

            NavigationStack {
                SavedView()
            }
            .tabItem { Label("Saved", systemImage: "bookmark") }

            NavigationStack {
               AccountView()
            }
            .tabItem { Label("Account", systemImage: "gear") }
        }
        .tint(.green)
    }
}
