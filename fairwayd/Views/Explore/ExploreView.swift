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
            .liquidGlass()
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


#Preview {
    // Every @EnvironmentObject the view (or its children) reads must be supplied —
    // CourseCardView pulls EngagementStore out of the environment too.
    let locationManager = LocationManager()
    let service = GolfCourseService()
    let store = EngagementStore()
    let finderService = GolfCourseFinderService(locationManager: locationManager)
    let exploreService = ExploreService(
        service: service,
        finderService: finderService,
        store: store,
        locationManager: locationManager
    )

    // Seed content so the preview shows cards instead of a spinner — location
    // never resolves in the canvas, so the real load path can't populate it.
    exploreService.topRatedCourses = GolfCourse.previewCourses
    exploreService.topSlopeCourses = GolfCourse.previewCourses.reversed()
    exploreService.loadingProgress = 1.0
    exploreService.hasLoadedCourses = true

    return NavigationStack {
        ExploreView()
    }
    .environmentObject(service)
    .environmentObject(finderService)
    .environmentObject(locationManager)
    .environmentObject(exploreService)
    .environmentObject(store)
}

#if DEBUG
extension GolfCourse {
    /// Sample data for previews only.
    static let previewCourses: [GolfCourse] = [
        make(id: "1", name: "Beverly Country Club", city: "Chicago", state: "IL",
             rating: 71.9, slope: 135, bogey: 92.4, yards: 6536, par: 71),
        make(id: "2", name: "Jackson Park Golf Course", city: "Chicago", state: "IL",
             rating: 68.2, slope: 118, bogey: 88.1, yards: 5538, par: 70),
        make(id: "3", name: "Harborside International", city: "Chicago", state: "IL",
             rating: 74.1, slope: 132, bogey: 95.8, yards: 7166, par: 72),
        make(id: "4", name: "Sydney R. Marovitz", city: "Chicago", state: "IL",
             rating: 65.4, slope: 112, bogey: 84.9, yards: 3265, par: 36)
    ]

    private static func make(
        id: String, name: String, city: String, state: String,
        rating: Double, slope: Int, bogey: Double, yards: Int, par: Int
    ) -> GolfCourse {
        GolfCourse(
            id: id,
            placeID: nil,
            club_name: name,
            course_name: name,
            location: Location(
                address: nil, city: city, state: state,
                country: "United States", latitude: 41.87, longitude: -87.62
            ),
            tees: Tees(
                female: nil,
                male: [Tee(
                    tee_name: "Blue",
                    course_rating: rating,
                    slope_rating: slope,
                    bogey_rating: bogey,
                    total_yards: yards,
                    total_meters: nil,
                    number_of_holes: par > 50 ? 18 : 9,
                    par_total: par,
                    front_course_rating: nil,
                    front_slope_rating: nil,
                    front_bogey_rating: nil,
                    back_course_rating: nil,
                    back_slope_rating: nil,
                    back_bogey_rating: nil,
                    holes: nil
                )]
            ),
            phone: "773-555-0100",
            website: "https://example.com"
        )
    }
}
#endif


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
