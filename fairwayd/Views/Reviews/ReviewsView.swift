//
//  ReviewsView.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 12/17/25.
//
import SwiftUI
import PhotosUI

struct ReviewsView: View {
    let courseID: Int
    let courseName: String
    
    @EnvironmentObject var reviewService: ReviewService
    @State private var isLoading = false
    @State private var errorText = ""
    @State private var showWriteReview = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isLoading {
                    ProgressView("Loading reviews…")
                        .frame(maxWidth: .infinity)
                } else if !errorText.isEmpty {
                    Text(errorText)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                } else if reviewService.courseReviews.isEmpty {
                    Text("No reviews yet. Be the first to review!")
                        .foregroundColor(.secondary)
                        .italic()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    ForEach(reviewService.courseReviews) { review in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(review.username)
                                    .bold()
                                Spacer()
                                if let date = review.createdAt {
                                    Text(date, style: .date)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            HStack(spacing: 2) {
                                ForEach(0..<5) { i in
                                    Image(systemName: i < review.rating ? "star.fill" : "star")
                                        .foregroundColor(.yellow)
                                }
                            }
                            .font(.caption)
                            
                            Text(review.comment)
                                .font(.body)
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            if let photoUrls = review.photoUrls {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(photoUrls, id: \.self) { urlString in
                                            if let url = URL(string: urlString) {
                                                AsyncImage(url: url) { imagePhase in
                                                    switch imagePhase {
                                                    case .success(let image):
                                                        image
                                                            .resizable()
                                                            .scaledToFill()
                                                            .frame(width: 150, height: 120)
                                                            .cornerRadius(8)
                                                    case .empty:
                                                        ProgressView()
                                                            .frame(width: 150, height: 120)
                                                    case .failure:
                                                        Image(systemName: "photo")
                                                            .frame(width: 150, height: 120)
                                                    @unknown default:
                                                        EmptyView()
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Reviews")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showWriteReview.toggle()
                } label: {
                    Image(systemName: "pencil")
                }
            }
        }
        .task {
            await loadReviews()
        }
        .refreshable {
            await loadReviews()
        }
        .sheet(isPresented: $showWriteReview) {
            Task {
                await loadReviews()
            }
        } content: {
            WriteReviewView(courseID: courseID, courseName: courseName)
        }
    }

    private func loadReviews() async {
        isLoading = true
        errorText = ""
        defer { isLoading = false }
        
        do {
            _ = try await reviewService.fetchReviewsByCourseName(courseName)
        } catch {
            await MainActor.run {
                errorText = error.localizedDescription
            }
        }
    }
}


struct LeaveReviewTabView: View {
    @StateObject private var reviewService = ReviewService()
    @State private var isLoading = false
    @State private var errorText = ""
    @State private var showWriteReview = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedImage : Image? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if isLoading {
                        ProgressView("Loading your reviews…")
                            .frame(maxWidth: .infinity)
                    } else if !errorText.isEmpty {
                        Text(errorText)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                    } else if reviewService.userReviews.isEmpty {
                        Text("You haven’t submitted any reviews yet.")
                            .foregroundColor(.secondary)
                            .italic()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        ForEach(reviewService.userReviews, id: \.id!) { review in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(review.username)
                                        .bold()
                                    Spacer()
                                    if let date = review.createdAt {
                                        Text(date, style: .date)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                }
                                
                                HStack(spacing: 2) {
                                    ForEach(0..<5) { i in
                                        Image(systemName: i < review.rating ? "star.fill" : "star")
                                            .foregroundColor(.yellow)
                                    }
                                }
                                .font(.caption)
                                
                                Text(review.comment)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Text("Course: \(review.courseName)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                
                                if let photoUrls = review.photoUrls, !photoUrls.isEmpty {
                                            ScrollView(.horizontal, showsIndicators: false) {
                                                HStack(spacing: 12) {
                                                    ForEach(photoUrls, id: \.self) { urlString in
                                                        if let url = URL(string: urlString) {
                                                            AsyncImage(url: url) { phase in
                                                                switch phase {
                                                                case .empty:
                                                                    ProgressView()
                                                                        .frame(width: 150, height: 120)
                                                                case .success(let image):
                                                                    image
                                                                        .resizable()
                                                                        .scaledToFill()
                                                                        .frame(width: 150, height: 120)
                                                                        .cornerRadius(8)
                                                                case .failure:
                                                                    Image(systemName: "photo")
                                                                        .frame(width: 150, height: 120)
                                                                @unknown default:
                                                                    EmptyView()
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                            .frame(height: 130)
                                        }
                                    }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                            
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Your Review History")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showWriteReview.toggle()
                    } label: {
                        Image(systemName: "pencil")
                    }
                }
            }
            .task {
                await loadUserReviews()
            }
            .refreshable {
                await loadUserReviews()
            }
            .sheet(isPresented: $showWriteReview) {
                Task {
                    await loadUserReviews()
                }
            } content: {
                WriteReviewView()
            }
        }
    }

    private func loadUserReviews() async {
        isLoading = true
        errorText = ""
        defer { isLoading = false }

        do {
            _ = try await reviewService.fetchUserReviews()
        } catch {
            await MainActor.run {
                errorText = error.localizedDescription
            }
        }
    }
}

