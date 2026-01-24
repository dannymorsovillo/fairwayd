//
//  CourseCard.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 12/17/25.
import SwiftUI

struct CourseCard: View {
    let title: String
    let subtitle: String
    let courseRating: Double?
    let slopeRating: Int?
    let bogeyRating: Double?
    let cardWidth: CGFloat
    let placeID: String?
    let location: String?
    
    let displayRatingType: RatingType?
    
    enum RatingType {
        case courseRating
        case slopeRating
        case bogeyRating
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            
            CourseImageView(
                placeID: placeID,
                courseName: title,
                location: location
            )
            .frame(width: cardWidth - 32, height: 120)
            .clipped()
            .cornerRadius(10)

            Text(title)
                .font(.headline)
                .lineLimit(2)
                .frame(height: 44, alignment: .top)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

        if let displayType = displayRatingType {
            switch displayType {
            case .courseRating:
                if let rating = courseRating {
                        Text("Rating: \(String(format: "%.1f", rating))")
                            .foregroundStyle(Color.green)
                            .font(.caption)
                            .bold()
                }
            case .slopeRating:
                if let slope = slopeRating {
                    Text("Slope: \(slope)")
                        .foregroundStyle(Color.green)
                        .font(.caption)
                        .bold()
                }
            case .bogeyRating:
                if let bogey = bogeyRating {
                    Text("Bogey: \(String(format: "%.1f", bogey))")
                        .foregroundStyle(Color.green)
                        .font(.caption)
                        .bold()
                }
            }
        }
            
    }
        .padding()
        .frame(width: cardWidth, height: 250)
        .frame(minHeight: 250)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .shadow(radius: 1)
    }
}
