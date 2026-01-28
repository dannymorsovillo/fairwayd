//
//  CourseImageView.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 12/27/25.
//

import SwiftUI

struct CourseImageView: View {
    let placeID: String?
    let courseName: String
    let location: String?

    @State private var courseImageURL: URL?

    var body: some View {
        AsyncImage(url: courseImageURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()

            case .empty:
                placeholder

            default:
                placeholder
            }
        }
        .clipped()
        .task {
            if let imageURL = await ImageService.shared.fetchCourseImage(
                placeID: placeID,
                name: courseName,
                location: location
            ) {
                courseImageURL = imageURL
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            Color.green.opacity(0.25)
            Image(systemName: "flag.fill")
                .font(.largeTitle)
                .foregroundColor(.black)
        }
    }
}
