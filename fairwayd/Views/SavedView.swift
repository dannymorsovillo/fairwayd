//
//  Saved.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 12/17/25.
//

import SwiftUI

struct SavedView: View {
    @EnvironmentObject var store: EngagementStore
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var finderService: GolfCourseFinderService
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if store.favorites.isEmpty {
                    Text("No saved courses yet.")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    VStack(spacing: 12) {
                        ForEach(store.favorites, id: \.self) { id in
                            if let snap = store.snapshots[id] {
                                NavigationLink {
                                    CourseDetailView(
                                        courseID: id,
                                        courseCache: CourseCache()
                                
                                    )
                                } label: {
                                    CourseCard(
                                        title: snap.title,
                                        subtitle: snap.subtitle,
                                        courseRating: nil,
                                        slopeRating: nil,
                                        bogeyRating: nil,
                                        cardWidth: UIScreen.main.bounds.width - 32,
                                        placeID: snap.placeId,
                                        location: snap.location,
                                        displayRatingType:  nil
                                    )
                                }
                                .buttonStyle(.plain)
                                .hoverEffect(.highlight)
                            }
                            
                        }
                    }
                }
            }
                    .navigationTitle("Saved")
        }
    }
}

