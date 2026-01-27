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
    @State private var selectedImageUrls: [String]?
    @State private var selectedImageIndex: Int = 0

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
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
                            
                            if let photoUrls = review.photoUrls, !photoUrls.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    LazyHStack(spacing: 12) {
                                        ForEach(Array(photoUrls.enumerated()), id: \.element) { index, urlString in
                                            if let url = URL(string: urlString) {
                                                AsyncImage(url: url) { imagePhase in
                                                    switch imagePhase {
                                                    case .success(let image):
                                                        image
                                                            .resizable()
                                                            .scaledToFill()
                                                            .frame(width: 100, height: 100)
                                                            .cornerRadius(8)
                                                            .clipped()
                                                            .onTapGesture {
                                                                print("Image URL:", urlString)
                                                                selectedImageIndex = index
                                                                selectedImageUrls = photoUrls
                                                            }
                                                    case .empty:
                                                        ProgressView()
                                                            .frame(width: 100, height: 100)
                                                    case .failure:
                                                        Image(systemName: "photo")
                                                            .frame(width: 100, height: 100)
                                                    @unknown default:
                                                        EmptyView()
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                .frame(height: 100)
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
        .sheet(isPresented: $showWriteReview, onDismiss: {
            Task {
                await loadReviews()
            }
        }) {
            WriteReviewView(courseID: courseID, courseName: courseName)
        }
        .fullScreenCover(isPresented: Binding(
            get: { selectedImageUrls != nil },
            set: { if !$0 { selectedImageUrls = nil } }
        )) {
            if let urls = selectedImageUrls {
                // Simple full-screen image viewer
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    TabView(selection: $selectedImageIndex) {
                        ForEach(Array(urls.enumerated()), id: \.offset) { index, urlString in
                            if let url = URL(string: urlString) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFit()
                                    case .empty:
                                        ProgressView()
                                    case .failure:
                                        VStack {
                                            Image(systemName: "photo")
                                                .font(.largeTitle)
                                            Text("Failed to load")
                                                .foregroundColor(.white)
                                        }
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                                .tag(index)
                            }
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                selectedImageUrls = nil
                                selectedImageIndex = 0
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                                    .padding()
                            }
                        }
                        Spacer()
                    }
                }
            }
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
    @EnvironmentObject var reviewService: ReviewService
    @EnvironmentObject var session: SessionStore
    @State private var isLoading = false
    @State private var errorText = ""
    @State private var showWriteReview = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedImage : Image? = nil
    @State private var showDeleteAlert = false
    @State private var selectedReview: Review?
    @State private var reviewToEdit: Review?
    @State private var selectedImageUrls: [String]?
    @State private var selectedImageIndex: Int = 0
    
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
                        Text("You haven't submitted any reviews yet.")
                            .foregroundColor(.secondary)
                            .italic()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        ForEach(reviewService.userReviews, id: \.id) { review in
                            VStack(alignment: .leading, spacing: 8) {
                                // Header with edit/delete buttons
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(review.username)
                                            .bold()
                                        
                                        if let date = review.createdAt {
                                            Text(date, style: .date)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    HStack(spacing: 20) {
                                        Button {
                                            reviewToEdit = review
                                        } label: {
                                            Image(systemName: "pencil")
                                                .foregroundColor(.blue)
                                        }
                                        
                                        Button {
                                            selectedReview = review
                                            showDeleteAlert = true
                                        } label: {
                                            Image(systemName: "trash")
                                                .foregroundColor(.red)
                                        }
                                    }
                                }
                                
                                // Stars
                                HStack(spacing: 2) {
                                    ForEach(0..<5) { i in
                                        Image(systemName: i < review.rating ? "star.fill" : "star")
                                            .foregroundColor(.yellow)
                                    }
                                }
                                .font(.caption)
                                
                                // Comment
                                Text(review.comment)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                // Course name
                                Text("Course: \(review.courseName)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                // Photos
                                if let photoUrls = review.photoUrls, !photoUrls.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        LazyHStack(spacing: 12) {
                                            ForEach(Array(photoUrls.enumerated()), id: \.element) { index, urlString in
                                                if let url = URL(string: urlString) {
                                                    AsyncImage(url: url) { phase in
                                                        switch phase {
                                                        case .empty:
                                                            ProgressView()
                                                                .frame(width: 100, height: 100)
                                                        case .success(let image):
                                                            image
                                                                .resizable()
                                                                .scaledToFill()
                                                                .frame(width: 100, height: 100)
                                                                .cornerRadius(8)
                                                                .clipped()
                                                                .onTapGesture {
                                                                    selectedImageUrls = photoUrls
                                                                    selectedImageIndex = index
                                                                }
                                                        case .failure:
                                                            Image(systemName: "photo")
                                                                .frame(width: 100, height: 100)
                                                        @unknown default:
                                                            EmptyView()
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    .frame(height: 100)
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
            if session.isAuthenticated {
                await loadUserReviews()
            }
        }
        .refreshable {
            if session.isAuthenticated {
                await loadUserReviews()
            }
        }
        .sheet(isPresented: $showWriteReview) {
            WriteReviewView()
        }
        .onChange(of: showWriteReview) { _, isShowing in
            if !isShowing {
                Task { await loadUserReviews() }
            }
        }
        .sheet(item: $reviewToEdit) { review in
            WriteReviewView(
                courseID: review.courseId,
                courseName: review.courseName,
                existingReview: review
            )
        }
        .onChange(of: reviewToEdit) { _, review in
            if review == nil {
                Task { await loadUserReviews() }
            }
        }
        .alert("Delete Review", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let review = selectedReview {
                    Task {
                        do {
                            try await reviewService.deleteReview(review)
                            await MainActor.run {
                                selectedReview = nil
                            }
                            await loadUserReviews()
                        } catch {
                            await MainActor.run {
                                errorText = "Failed to delete review. Please try again later."
                            }
                        }
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete this review?")
        }
        .fullScreenCover(isPresented: Binding(
            get: { selectedImageUrls != nil },
            set: { if !$0 { selectedImageUrls = nil } }
        )) {
            if let urls = selectedImageUrls {
                // Simple full-screen image viewer
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    TabView(selection: $selectedImageIndex) {
                        ForEach(Array(urls.enumerated()), id: \.offset) { index, urlString in
                            if let url = URL(string: urlString) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFit()
                                    case .empty:
                                        ProgressView()
                                    case .failure:
                                        VStack {
                                            Image(systemName: "photo")
                                                .font(.largeTitle)
                                            Text("Failed to load")
                                                .foregroundColor(.white)
                                        }
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                                .tag(index)
                            }
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                selectedImageUrls = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                                    .padding()
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
    }
    
    private func loadUserReviews() async {
        guard session.isAuthenticated else {
            await MainActor.run {
                errorText = "Please sign in to view your reviews"
            }
            return
        }
        
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
