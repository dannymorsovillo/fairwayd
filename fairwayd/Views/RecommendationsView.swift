//
//  RecommendationsView.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 12/30/25.
//

import SwiftUI

struct RecommendationsView: View {
    @EnvironmentObject var service: GolfCourseService// GolfCourseAPI
    @EnvironmentObject var finderService: GolfCourseFinderService// RapidAPI
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var store: EngagementStore
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var recommendationService: RecommendationService
    
    @State private var hasLoadedCourses = false
    @State private var showRecInfo = false
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    
    var body: some View {
        ScrollView {
            if recommendationService.recommendedCourses.isEmpty {
                ProgressView("Finding courses for you ...")
                    .padding()
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(recommendationService.recommendedCourses) { course in
                        CourseCardView(
                            course: course,
                            ratingType: nil
                        )
                        .aspectRatio(0.8, contentMode: .fit)
                    }
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("AI Based")
        .navigationSubtitle("Recommendations For You")
        .toolbar{
            ToolbarItem {
                moreInfoButton
            }
        }
        .task() {
            locationManager.requestLocation()
            }
        .onChange(of: locationManager.location) { _, newLocation in
            guard
                let loc = newLocation,
                !hasLoadedCourses
            else { return }
            Task {
            await recommendationService.loadRecCourses(
                    for: session.currentUser?.skillLevel ?? .midHandicap,
                    using: loc
                )
                await MainActor.run {
                    hasLoadedCourses = true
                }
            }
        }
        .refreshable {
            guard let loc = locationManager.location else { return }
            Task {
                await recommendationService.loadRecCourses(
                    for: session.currentUser?.skillLevel ?? .midHandicap,
                    using: loc
                )
            }
        }
    }
    
    private var moreInfoButton: some View {
        Button("Read more")
        {
            showRecInfo = true
        }
        .buttonStyle(.borderless)
        .padding()
        .sheet(isPresented: $showRecInfo) {
            RecView()
                .presentationDetents([.height(500)])
                .ignoresSafeArea()
            
        }
    }
}

struct RecView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How Courses Are Recommended")
                .font(.largeTitle.bold())
            Text("You select a handicap cateogory \(Text("scratch, low, mid, or high").bold()) which is then mapped to an estimated handicap number.")
            Text("Then an AI model is trained on a data set of the meta data below.")
            
            ScrollView(.horizontal) {
                LazyHStack(spacing: 8) {
                    Text("course_rating")
                    Text("slope_rating")
                    Text("bogey_rating")
                    Text("total_par")
                    Text("handicap")
                    Text("total_yards")
                    Text("expected_score_diff")
                }
                .font(.system(size: 14, design: .monospaced).bold())
                .padding(2)
                .background(Color.green)
                .cornerRadius(8)
                .fixedSize()
            }
            
            Text("Scroll to see full row.")
                .font(.caption.bold())
                .frame(maxWidth: .infinity, alignment: .center)
            
            VStack(alignment: .leading, spacing: 16) {
                Text("\(Text("expected_score_diff").bold()) is the target variable. (what the model learns to predict)")
                Text("The target represents how far above or below par a user is expected to score on a a course.")
                Text("Courses tailored to your skill are then returned to you.")
            }
            .multilineTextAlignment(.leading)
        }
        .font(.system(size: 14))
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        
    }
}

