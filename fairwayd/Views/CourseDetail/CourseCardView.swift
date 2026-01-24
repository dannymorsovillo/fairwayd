//
//  CourseView.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 1/15/26.
//

import SwiftUI

struct CourseCardView: View {
    @EnvironmentObject var store: EngagementStore
    
    let course: GolfCourse
    let ratingType: CourseCard.RatingType?
    private let aspectRatio: CGFloat = 0.7
    
    var body: some View {
        NavigationLink {
            CourseDetailView(courseID: course.id, courseCache: CourseCache())
        } label: {
            CourseCard(
                title: course.titleText,
                subtitle: course.subtitleText,
                courseRating: course.bestCourseRating,
                slopeRating: course.bestSlopeRating,
                bogeyRating: course.bestBogeyRating,
                cardWidth: (UIScreen.main.bounds.width - 48) / 2,
                placeID: course.placeID,
                location: course.subtitleText,
                displayRatingType: ratingType
            )
            .frame(height: ((UIScreen.main.bounds.width - 48) / 2) / aspectRatio)
        }
        .buttonStyle(.plain)
        .onAppear {
            store.saveSnapshot(
                id: course.id,
                title: course.titleText,
                subtitle: course.subtitleText,
                placeId: course.placeID,
                location: course.subtitleText,
                userId: nil
            )
        }
    }
}
