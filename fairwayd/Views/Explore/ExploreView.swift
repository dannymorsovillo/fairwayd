//
//  ExploreView.swift
//  fairwayd
//
//  Updated to show courses incrementally as they load
//

import SwiftUI
import CoreLocation

struct ExploreView: View {
    @EnvironmentObject var service: GolfCourseService
    @EnvironmentObject var finderService: GolfCourseFinderService
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var exploreService: ExploreService
    @EnvironmentObject var store: EngagementStore
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        VStack(spacing: 12) {
            searchBar
            
            // Loading states
            if exploreService.isSearching {
                loadingIndicator(text: "Searching...")
            } else if exploreService.mode == .explore && isExploreEmpty && exploreService.loadingProgress < 1.0 {
                loadingIndicator(text: "Loading nearby courses...")
            }
            
            // Error display
            if !exploreService.errorText.isEmpty {
                Text(exploreService.errorText)
                    .foregroundColor(.red)
                    .padding()
            }
            
            // Progress bar when loading explore content
            if exploreService.mode == .explore && !isExploreEmpty && exploreService.loadingProgress < 1.0 {
                progressBar
            }
            
            ScrollView {
                if exploreService.mode == .searching {
                    searchResultsGrid
                } else {
                    exploreContent
                }
            }
        }
        .navigationTitle("Explore")
        .task {
            locationManager.requestLocation()
        }
        .onChange(of: locationManager.location) { _, newLocation in
            guard let loc = newLocation else { return }
            exploreService.loadDefaultExploreIfNeeded(using: loc)
        }
        .refreshable {
            guard let loc = locationManager.location else { return }
            exploreService.hasLoadedCourses = false
            exploreService.loadDefaultExplore(using: loc, forceReload: true)
        }
    }
    
    // computed properties
    private var isExploreEmpty: Bool {
        exploreService.topRatedCourses.isEmpty &&
        exploreService.topSlopeCourses.isEmpty &&
        exploreService.topBogeyCourses.isEmpty
    }
    
    // subviews
    private var searchBar: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search courses…", text: $exploreService.query)
                    .submitLabel(.search)
                    .onSubmit { exploreService.search() }
                    .autocorrectionDisabled()
                
                if !exploreService.query.isEmpty {
                    Button {
                        exploreService.clearSearch()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            Button("Search") {
                exploreService.search()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal)
    }
    
    private func loadingIndicator(text: String) -> some View {
        VStack(spacing: 8) {
            ProgressView()
            Text(text)
                .foregroundColor(.secondary)
                .font(.subheadline)
        }
        .padding()
    }
    
    private var progressBar: some View {
        VStack(spacing: 4) {
            ProgressView(value: exploreService.loadingProgress)
                .progressViewStyle(.linear)
            
            Text("Loading courses... \(Int(exploreService.loadingProgress * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var searchResultsGrid: some View {
        if exploreService.searchResults.isEmpty && !exploreService.isSearching {
            Text("No results found")
                .foregroundColor(.secondary)
                .padding()
        } else {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(exploreService.searchResults) { course in
                    CourseCardView(course: course, ratingType: nil)
                        .aspectRatio(0.8, contentMode: .fit)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .padding()
            .animation(.easeInOut(duration: 0.25), value: exploreService.searchResults.count)
        }
    }
    
    @ViewBuilder
    private var exploreContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            if !exploreService.topRatedCourses.isEmpty {
                TopSectionView(
                    title: "Highest Rating",
                    courses: exploreService.topRatedCourses,
                    store: store,
                    locationManager: locationManager,
                    finderService: finderService,
                    ratingType: .courseRating
                )
            }
            
            if !exploreService.topSlopeCourses.isEmpty {
                TopSectionView(
                    title: "Highest Slope Rating",
                    courses: exploreService.topSlopeCourses,
                    store: store,
                    locationManager: locationManager,
                    finderService: finderService,
                    ratingType: .slopeRating
                )
            }
            
            if !exploreService.topBogeyCourses.isEmpty {
                TopSectionView(
                    title: "Highest Bogey Rating",
                    courses: exploreService.topBogeyCourses,
                    store: store,
                    locationManager: locationManager,
                    finderService: finderService,
                    ratingType: .bogeyRating
                )
            }
        }
        .padding(.horizontal)
        .animation(.easeInOut(duration: 0.3), value: exploreService.topRatedCourses.count)
        .animation(.easeInOut(duration: 0.3), value: exploreService.topSlopeCourses.count)
        .animation(.easeInOut(duration: 0.3), value: exploreService.topBogeyCourses.count)
    }
}


// top section view
struct TopSectionView: View {
    let title: String
    let courses: [GolfCourse]
    let store: EngagementStore
    let locationManager: LocationManager
    let finderService: GolfCourseFinderService
    let ratingType: CourseCard.RatingType?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.title2)
                .bold()
                .padding(.horizontal, 4)
            
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(courses) { course in
                    CourseCardView(course: course, ratingType: ratingType)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
        }
    }
}
