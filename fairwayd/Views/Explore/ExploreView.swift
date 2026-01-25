//
//  ExploreView.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 12/17/25.
//

import SwiftUI
import CoreLocation


struct ExploreView: View {
    @EnvironmentObject var service: GolfCourseService// GolfCourseAPI
    @EnvironmentObject var finderService: GolfCourseFinderService// RapidAPI
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var exploreService: ExploreService
    @EnvironmentObject var store: EngagementStore
    

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    private  var coursesToShow: [GolfCourse] {
        if exploreService.mode == .searching {
            return service.courses
        }
        return []
    }
        
    var body: some View {
        VStack(spacing: 12) {
            searchBar
            if exploreService.isSearching {
                ProgressView("Searching")
                    .padding()
            } else if exploreService.mode == .explore && exploreService.topRatedCourses.isEmpty && exploreService.topSlopeCourses.isEmpty && exploreService.topBogeyCourses.isEmpty {
                ProgressView("Loading nearby courses...")
                    .padding()
            }
            
            if !exploreService.errorText.isEmpty {
                Text(exploreService.errorText)
                    .foregroundColor(.red)
                    .padding()
            }
            
            
            ScrollView {
                if !coursesToShow.isEmpty {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(coursesToShow) { course in
                            CourseCardView(course: course, ratingType: nil)
                                .aspectRatio(0.8, contentMode: .fit)
                        }
                    }
                    .padding()
                } else {
                    
                    VStack(alignment: .leading, spacing: 24) {
                        if !exploreService.topRatedCourses.isEmpty {
                            TopSectionView(title: "Highest Rating", courses: exploreService.topRatedCourses, store: store, locationManager: locationManager, finderService: finderService, ratingType: .courseRating)
                        }
                        if !exploreService.topSlopeCourses.isEmpty {
                            TopSectionView(title: "Highest Slope Rating", courses: exploreService.topSlopeCourses, store: store, locationManager: locationManager, finderService: finderService, ratingType: .slopeRating)
                        }
                        if !exploreService.topBogeyCourses.isEmpty {
                            TopSectionView(title: "Highest Bogey Rating", courses: exploreService.topBogeyCourses, store: store, locationManager: locationManager, finderService: finderService, ratingType: .bogeyRating)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .navigationTitle("Explore")
        .task {
            locationManager.requestLocation()
        }
        
        .onChange(of: locationManager.location) { _, newLocation in
            guard let loc = newLocation  else { return }
            Task {
                await exploreService.loadDefaultExploreIfNeeded(using: loc)
            }
            
        }
        
        .refreshable {
            guard let loc = locationManager.location else { return }
            
            exploreService.hasLoadedCourses = false
            
            await exploreService.loadDefaultExplore(
                using: loc,
                forceReload: true
            )
        }
    }
    
    private var searchBar: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search courses …", text: $exploreService.query)
                    .submitLabel(.search)
                    .onSubmit { exploreService.search() }
                    .autocorrectionDisabled()
                
                if !exploreService.query.isEmpty {
                    Button {
                        exploreService.query = ""
                        service.courses = []
                        exploreService.isSearching = false
                        exploreService.errorText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            Button("Search") { exploreService.search() }
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal)
    }
    
    
}

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
                }
            }
        }
    }
}


