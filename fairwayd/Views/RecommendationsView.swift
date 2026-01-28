//
//  RecommendationsView.swift
//  fairwayd
//
//  Updated to show courses incrementally as they load
//

import SwiftUI

struct RecommendationsView: View {
    @EnvironmentObject var service: GolfCourseService
    @EnvironmentObject var finderService: GolfCourseFinderService
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
            VStack(spacing: 16) {
                // Show loading indicator only when empty and loading
                if recommendationService.recommendedCourses.isEmpty && recommendationService.isLoading {
                    loadingView
                }
                
                // Progress bar when loading with existing content
                if recommendationService.isLoading && !recommendationService.recommendedCourses.isEmpty {
                    progressBar
                }
                
                // Show courses as they arrive
                if !recommendationService.recommendedCourses.isEmpty {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(recommendationService.recommendedCourses) { course in
                            CourseCardView(course: course, ratingType: nil)
                                .aspectRatio(0.8, contentMode: .fit)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                    }
                    .padding(.horizontal)
                    .animation(.easeInOut(duration: 0.3), value: recommendationService.recommendedCourses.count)
                }
                
                // Error message
                if !recommendationService.errorText.isEmpty {
                    Text(recommendationService.errorText)
                        .foregroundColor(.red)
                        .padding()
                }
            }
        }
        .navigationTitle("AI Recommendations")
        .toolbar {
            ToolbarItem {
                moreInfoButton
            }
        }
        .task {
            locationManager.requestLocation()
        }
        .onChange(of: locationManager.location) { _, newLocation in
            guard let loc = newLocation, !hasLoadedCourses else { return }
            
            recommendationService.loadRecCourses(
                for: session.currentUser?.skillLevel ?? .midHandicap,
                using: loc
            )
            hasLoadedCourses = true
        }
        .refreshable {
            guard let loc = locationManager.location else { return }
            
            recommendationService.loadRecCourses(
                for: session.currentUser?.skillLevel ?? .midHandicap,
                using: loc,
                forceReload: true
            )
        }
    }
    
 
    // subviews
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Finding courses for you...")
                .foregroundColor(.secondary)
            
            // Show progress percentage
            if recommendationService.loadingProgress > 0 {
                Text("\(Int(recommendationService.loadingProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 40)
    }
    
    private var progressBar: some View {
        VStack(spacing: 4) {
            ProgressView(value: recommendationService.loadingProgress)
                .progressViewStyle(.linear)
            
            Text("Loading more courses... \(Int(recommendationService.loadingProgress * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var moreInfoButton: some View {
        Button("Read more") {
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


// info sheet
struct RecView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How Courses Are Recommended")
                .font(.largeTitle.bold())
            
            Text("You select a handicap category \(Text("scratch, low, mid, or high").bold()) which is then mapped to an estimated handicap number.")
            
            Text("Then an AI model is trained on a data set of the metadata below.")
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(["course_rating", "slope_rating", "bogey_rating", "total_par", "handicap", "total_yards", "expected_score_diff"], id: \.self) { item in
                        Text(item)
                            .font(.system(size: 14, design: .monospaced).bold())
                            .foregroundStyle(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green)
                            .cornerRadius(6)
                    }
                }
                .padding(.horizontal, 2)
                .fixedSize(horizontal: false, vertical: true) 
            }
            
            Text("Scroll to see full row.")
                .font(.caption.bold())
                .frame(maxWidth: .infinity, alignment: .center)
            
            VStack(alignment: .leading, spacing: 16) {
                Text("\(Text("expected_score_diff").bold()) is the target variable (what the model learns to predict).")
                Text("The target represents how far above or below par a user is expected to score on a course.")
                Text("Courses tailored to your skill are then returned to you.")
            }
            .multilineTextAlignment(.leading)
        }
        .font(.system(size: 14))
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
