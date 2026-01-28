//
//  ReviewsView.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 12/17/25.
//
import SwiftUI
import PhotosUI


struct FullScreenImageViewer: View {
    let urls: [String]
    @Binding var selectedIndex: Int
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            imageTabView
            dismissButton
        }
    }
    
    private var imageTabView: some View {
        TabView(selection: $selectedIndex) {
            ForEach(Array(urls.enumerated()), id: \.offset) { index, urlString in
                imageView(for: urlString)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
    }
    
    @ViewBuilder
    private func imageView(for urlString: String) -> some View {
        if let url = URL(string: urlString) {
            CachedAsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFit()
            } placeholder: {
                ProgressView()
                    .tint(.white)
            }
        }
    }
    
    private var dismissButton: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: onDismiss) {
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


struct ReviewPhotoGrid: View {
    let photoUrls: [String]
    let onTap: ((Int) -> Void)?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(Array(photoUrls.enumerated()), id: \.element) { index, urlString in
                    photoThumbnail(urlString: urlString, index: index)
                }
            }
        }
        .frame(height: 100)
    }
    
    @ViewBuilder
    private func photoThumbnail(urlString: String, index: Int) -> some View {
        if let url = URL(string: urlString) {
            CachedAsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .cornerRadius(8)
                    .clipped()
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: 100, height: 100)
                    .overlay { ProgressView() }
            }
            .onTapGesture {
                onTap?(index)
            }
        }
    }
}


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
                reviewContent
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
            Task { await loadReviews() }
        }) {
            WriteReviewView(courseID: courseID, courseName: courseName)
        }
        .fullScreenCover(isPresented: showingImageViewer) {
            if let urls = selectedImageUrls {
                FullScreenImageViewer(
                    urls: urls,
                    selectedIndex: $selectedImageIndex,
                    onDismiss: dismissImageViewer
                )
            }
        }
    }
    
    private var showingImageViewer: Binding<Bool> {
        Binding(
            get: { selectedImageUrls != nil },
            set: { if !$0 { selectedImageUrls = nil } }
        )
    }
    
    @ViewBuilder
    private var reviewContent: some View {
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
                reviewCard(for: review)
            }
        }
    }
    
    
    private func reviewCard(for review: Review) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            reviewHeader(for: review)
            starRating(for: review.rating)
            
            Text(review.comment)
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            if let photoUrls = review.photoUrls, !photoUrls.isEmpty {
                ReviewPhotoGrid(photoUrls: photoUrls) { index in
                    selectedImageIndex = index
                    selectedImageUrls = photoUrls
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private func reviewHeader(for review: Review) -> some View {
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
    }
    
    private func starRating(for rating: Int) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { i in
                Image(systemName: i < rating ? "star.fill" : "star")
                    .foregroundColor(.yellow)
            }
        }
        .font(.caption)
    }
    
    
    private func dismissImageViewer() {
        selectedImageUrls = nil
        selectedImageIndex = 0
    }

    private func loadReviews() async {
        isLoading = true
        errorText = ""
        defer { isLoading = false }
        
        do {
            _ = try await reviewService.fetchReviewsByCourseName(courseName)
        } catch {
            errorText = error.localizedDescription
        }
    }
}


struct LeaveReviewTabView: View {
    @EnvironmentObject var reviewService: ReviewService
    @EnvironmentObject var session: SessionStore
    @State private var isLoading = false
    @State private var errorText = ""
    @State private var showWriteReview = false
    @State private var showDeleteAlert = false
    @State private var selectedReview: Review?
    @State private var reviewToEdit: Review?
    @State private var selectedImageUrls: [String]?
    @State private var selectedImageIndex: Int = 0
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    reviewContent
                }
                .padding()
            }
        }
        .navigationTitle("Your Review History")
        .toolbar { toolbarContent }
        .task { await loadIfAuthenticated() }
        .refreshable { await loadIfAuthenticated() }
        .sheet(isPresented: $showWriteReview, onDismiss: { Task { await loadUserReviews() } }) {
            WriteReviewView()
        }
        .sheet(item: $reviewToEdit) { review in
            WriteReviewView(
                courseID: review.courseId,
                courseName: review.courseName,
                existingReview: review
            )
        }
        .alert("Delete Review", isPresented: $showDeleteAlert) {
            deleteAlertButtons
        } message: {
            Text("Are you sure you want to delete this review?")
        }
        .fullScreenCover(isPresented: showingImageViewer) {
            if let urls = selectedImageUrls {
                FullScreenImageViewer(
                    urls: urls,
                    selectedIndex: $selectedImageIndex,
                    onDismiss: { selectedImageUrls = nil }
                )
            }
        }
    }
    
    
    private var showingImageViewer: Binding<Bool> {
        Binding(
            get: { selectedImageUrls != nil },
            set: { if !$0 { selectedImageUrls = nil } }
        )
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                showWriteReview.toggle()
            } label: {
                Image(systemName: "pencil")
            }
        }
    }
    
    @ViewBuilder
    private var deleteAlertButtons: some View {
        Button("Cancel", role: .cancel) { }
        Button("Delete", role: .destructive) {
            deleteSelectedReview()
        }
    }
    
    @ViewBuilder
    private var reviewContent: some View {
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
                userReviewCard(for: review)
            }
        }
    }
    
    private func userReviewCard(for review: Review) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            userReviewHeader(for: review)
            starRating(for: review.rating)
            
            Text(review.comment)
                .font(.body)
                .foregroundColor(.primary)
            
            Text("Course: \(review.courseName)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let photoUrls = review.photoUrls, !photoUrls.isEmpty {
                ReviewPhotoGrid(photoUrls: photoUrls) { index in
                    selectedImageUrls = photoUrls
                    selectedImageIndex = index
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private func userReviewHeader(for review: Review) -> some View {
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
                Button { reviewToEdit = review } label: {
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
    }
    
    private func starRating(for rating: Int) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { i in
                Image(systemName: i < rating ? "star.fill" : "star")
                    .foregroundColor(.yellow)
            }
        }
        .font(.caption)
    }
    
    
    private func loadIfAuthenticated() async {
        if session.isAuthenticated {
            await loadUserReviews()
        }
    }
    
    private func deleteSelectedReview() {
        guard let review = selectedReview else { return }
        
        Task {
            do {
                try await reviewService.deleteReview(review)
                selectedReview = nil
                await loadUserReviews()
            } catch {
                errorText = "Failed to delete review. Please try again later."
            }
        }
    }
    
    private func loadUserReviews() async {
        guard session.isAuthenticated else {
            errorText = "Please sign in to view your reviews"
            return
        }
        
        isLoading = true
        errorText = ""
        defer { isLoading = false }

        do {
            _ = try await reviewService.fetchUserReviews()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
