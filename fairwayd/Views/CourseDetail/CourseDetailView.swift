//
//  CourseDetailView.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 12/17/25.
//

import SwiftUI
import CoreLocation

struct CourseDetailView: View {
    let courseID: String
    let courseCache: CourseCache
    
    @EnvironmentObject var store: EngagementStore
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var finderService: GolfCourseFinderService
    @EnvironmentObject private var service: GolfCourseService
    
    @State private var course: GolfCourse?
    @State private var errorText = ""
    @State private var isLoading = false
    @State private var selectedTeeIndex = 0
    
    private var selectedTeeName: String {
        guard let course = course,
              selectedTeeIndex < course.allTees.count else {
            return "No tee selected"
        }
        
        let tee = course.allTees[selectedTeeIndex]
        return tee.tee_name ?? "Tee \(selectedTeeIndex + 1)"
    }


    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if isLoading {
                    ProgressView("Loading course…")
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if let course{
                    headerSection(course)
                    courseContactInfoSection(course)
                    reviewsEntrySection()
                    quickStatsSection(course)
                    teeSection(course)
                } else if !errorText.isEmpty {
                    Text(errorText)
                        .foregroundColor(.red)
                }
            }
            .padding()
        }
        .navigationTitle("Course")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task {
                       await store.toggleFavorite(courseID)
                    }
                } label: {
                    Image(systemName: store.isFavorite(courseID) ? "bookmark.fill" : "bookmark")
                }
                .disabled(course == nil)
            }
        }
        .task {
            await load() }
    }

    private func headerSection(_ course: GolfCourse) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(course.titleText)
                .font(.title2)
                .bold()
            Text(course.subtitleText)
                .foregroundColor(.secondary)
        }
    }

    private func quickStatsSection(_ course: GolfCourse) -> some View {
        let bestTee = course.allTees.first
        return HStack(spacing: 16) {
            stat("Rating", bestTee?.course_rating.map { String(format: "%.1f", $0) })
            stat("Slope", bestTee?.slope_rating.map(String.init))
            ///Current RapidAPI does not have a bogey endpoint
            //stat("Bogey", bestTee?.bogey_rating.map { String(format: "%.1f", $0) })
            stat("Par", bestTee?.par_total.map(String.init))
            stat("Yards", bestTee?.total_yards.map(String.init))
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func stat(_ title: String, _ value: String?) -> some View {
        VStack {
            Text(value ?? "—")
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func teeSection(_ course: GolfCourse) -> some View {
        let tees = course.allTees
        return VStack(alignment: .leading, spacing: 16) {
            if !tees.isEmpty {
                Picker("Tee", selection: $selectedTeeIndex) {
                        ForEach(tees.indices, id: \.self) { i in
                            let name = tees[i].tee_name ?? "Tee \(i + 1)"
                            Text(name).tag(i)
                        }
                }
                .pickerStyle(.segmented)

                let tee = tees[min(selectedTeeIndex, tees.count - 1)]
                VStack(alignment: .leading, spacing: 6) {
                    Text(selectedTeeName)
                        .font(.headline)
                    Text("Rating: \(tee.course_rating ?? 0, specifier: "%.1f") • Slope: \(tee.slope_rating ?? 0)")
                    Text("Par: \(tee.par_total ?? 0) • Yards: \(tee.total_yards ?? 0) • Holes: \(tee.number_of_holes ?? 0)")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)

                holesSection(tee)
            }
        }
    }
    
    private func courseContactInfoSection(_ course: GolfCourse) -> some View {
        
        return HStack {
            if let coursePhone = course.phone, !coursePhone.isEmpty {
                let cleanedPhone = coursePhone.filter { "0123456789+" .contains($0) }
                
                Button {
                    if let phoneUrl = URL(string: "tel://\(cleanedPhone)"),
                       UIApplication.shared.canOpenURL(phoneUrl) {
                        UIApplication.shared.open(phoneUrl)
                    }
                } label : {
                    Image(systemName: "phone")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
            }
            
            if let courseWebsite = course.website, !courseWebsite.isEmpty {
                let urlString = courseWebsite.hasPrefix("http") ? courseWebsite: "https://\(courseWebsite)"
                if let webUrl = URL(string: urlString) {
                    Link(destination: webUrl) {
                        Image(systemName: "link")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                    }
                }
            }
        }
        .foregroundStyle(.secondary)
    }
    
    private func holesSection(_ tee: Tee) -> some View {
        Group {
            if let holes = tee.holes, !holes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    // Column headers
                    HStack(spacing: 8) {
                        Text("Hole").frame(width: 50, alignment: .leading)
                        Text("Par").frame(width: 30, alignment: .trailing)
                        Text("Yds").frame(width: 40, alignment: .trailing)
                        Text("HCP").frame(width: 30, alignment: .trailing)
                        Spacer()
                    }
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)

                    // Hole details
                    ForEach(holes.indices, id: \.self) { i in
                        let h = holes[i]
                        HStack(spacing: 8) {
                            Text("\(i + 1)").frame(width: 50, alignment: .leading)
                            Text("\(h.par ?? 0)").frame(width: 30, alignment: .trailing)
                            Text("\(h.yardage ?? 0)").frame(width: 40, alignment: .trailing)
                            Text("\(h.handicap ?? 0)").frame(width: 30, alignment: .trailing)
                            Spacer()
                        }
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
        }
    }

    private func reviewsEntrySection() -> some View {
        VStack(spacing: 12) {
            Divider()
            NavigationLink {
                if let course = course {
                    ReviewsView(courseID: courseID, courseName: course.titleText)
                }
            } label: {
                HStack {
                    Text("Reviews")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    @MainActor
    private func load() async {
        if let existingCourse = course, existingCourse.tees != nil { return }

        isLoading = true
        errorText = ""

        do {
            let fetched = try await service.fetchCourse(id: courseID)

            var enrichedCourse = fetched
            if let loc = locationManager.location {
                let nearbyCourses: [GolfCourse]
                if let cached = await courseCache.get(for: loc) {
                    nearbyCourses = cached
                } else {
                    let clubs = try await finderService.fetchNearbyCourses(
                        latitude: loc.coordinate.latitude,
                        longitude: loc.coordinate.longitude,
                        miles: 50
                    )
                    nearbyCourses = finderService.mapNearbyClubsToGolfCourses(clubs)
                    await courseCache.set(nearbyCourses, for: loc)
                }

                enrichedCourse = await finderService.enrichCourseWContactInfo(fetched, nearbyCourses: nearbyCourses)
            }

            await MainActor.run {
                course = enrichedCourse
                store.saveSnapshot(
                    id: enrichedCourse.id,
                    title: enrichedCourse.titleText,
                    subtitle: enrichedCourse.subtitleText,
                    placeId: enrichedCourse.placeID,
                    location: enrichedCourse.subtitleText,
                    userId: nil
                )
                isLoading = false
            }

        } catch {
            await MainActor.run {
                errorText = error.localizedDescription
                isLoading = false
            }
        }
    }


}

