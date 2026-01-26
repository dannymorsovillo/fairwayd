//
//  WriteReviewView.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 12/22/25.
//
import SwiftUI
import UIKit

enum WriteReviewMode {
    case accessedFromCourseDetail
    case accessedFromCreate
}

struct WriteReviewView: View {
    let courseID: Int?
    let courseName: String?
    let accessMode: WriteReviewMode
    let existingReview: Review?
    
    init(courseID: Int? = nil, courseName: String? = nil, existingReview: Review? = nil) {
        self.courseID = courseID
        self.courseName = courseName
        self.existingReview = existingReview
        
        self.accessMode = courseID == nil
        ? .accessedFromCreate
        : .accessedFromCourseDetail
    }
    
    @EnvironmentObject var reviewService: ReviewService
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var session: SessionStore
    
    
    @State private var username = ""
    @State private var rating = 5
    @State private var comment = ""
    @State private var date = Date()
    @State private var showCamera = false
    @State private var capturedImages: [UIImage] = []
    @State private var isSubmitting = false
    @State private var courseNameInput: String = ""
    @State private var courseIDMapped: Int? = nil
    @State private var courseSuggestions: [GolfCourse] = []
    @State private var errorMessage = ""
    @State private var existingPhotoUrls: [String] = []
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            Form {
                if existingReview == nil {
                    Section(header: Text("Course Name")) {
                        TextField("Enter course name", text: $courseNameInput).bold()
                            .focused($isTextFieldFocused)
                            .onChange(of: courseNameInput) { oldValue, newValue in
                                Task {
                                    if !newValue.isEmpty {
                                        do {
                                            courseSuggestions = try await GolfCourseService().searchCourses(query: newValue)
                                        }catch {
                                            courseSuggestions = []
                                        }
                                    } else {
                                        courseSuggestions = []
                                        courseIDMapped = nil
                                    }
                                }
                            }
                        
                        if !courseSuggestions.isEmpty {
                            ScrollView {
                                VStack(spacing: 0) {
                                    ForEach(courseSuggestions, id: \.id) { course in
                                        HStack {
                                            Text(course.titleText)
                                                .foregroundColor(.primary)
                                            Spacer()
                                        }
                                        .padding(.vertical, 12)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            // Dismiss keyboard first
                                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                            
                                            // Then update values
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                courseNameInput = course.titleText
                                                courseIDMapped = course.id
                                                courseSuggestions = []
                                            }
                                        }
                                        
                                        if course.id != courseSuggestions.last?.id {
                                            Divider()
                                        }
                                    }
                                }
                            }
                            .frame(height: 150)
                        }
                        
                        Text("Date: \(date, style: .date)")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                } else {
                    Section(header: Text("Course")) {
                        HStack {
                            Text(existingReview?.courseName ?? courseName ?? "Unknown Course")
                                .bold()
                            Spacer()
                        }
                        Text("Date: \(date, style: .date)")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                }
                
                Section(header: Text("Your Name")) {
                    TextField("Enter your name", text: $username)
                }
                
                Section(header: Text("Rating")) {
                    HStack {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .foregroundColor(.yellow)
                                .font(.title2)
                                .onTapGesture { rating = star }
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("Photos")) {
                    Button {
                        showCamera = true
                    } label: {
                        HStack {
                            Image(systemName: "camera.fill")
                            Text("Add photo")
                            Spacer()
                        }
                        .padding(.vertical, 6)
                        .foregroundStyle(Color.green)
                    }
                    .buttonStyle(.borderless)
                    
                    if !existingPhotoUrls.isEmpty || !capturedImages.isEmpty {
                        Text("\(existingPhotoUrls.count + capturedImages.count) photo(s)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                // Existing photo URLs (thumbnails)
                                ForEach(existingPhotoUrls, id: \.self) { urlString in
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
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                            case .failure:
                                                Image(systemName: "photo")
                                                    .frame(width: 100, height: 100)
                                                    .background(Color(.systemGray5))
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                            @unknown default:
                                                EmptyView()
                                            }
                                        }
                                    }
                                }
                                
                                // Newly captured images (session-only)
                                ForEach(capturedImages, id: \.self) { image in
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .frame(height: 100)
                    }
                }
            
                Section(header: Text("Review")) {
                    TextEditor(text: $comment)
                        .frame(height: 150)
                }
                
                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
                
                Section {
                    Button {
                        submitReview()
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Submit Review")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(username.isEmpty || comment.isEmpty || isSubmitting)
                }
            }
            .navigationTitle(existingReview != nil ? "Edit Review" : "Write Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraView(capturedImages: $capturedImages, existingPhotoUrls: $existingPhotoUrls)
        }
        .onAppear{
            if let review = existingReview {
                username = review.username
                rating = review.rating
                comment = review.comment
                
                if let createdAt = review.createdAt{
                    date = createdAt
                }
                
                if let photoUrls = review.photoUrls {
                    existingPhotoUrls = photoUrls
                }
            } else {
                if let courseName = courseName, !courseName.isEmpty {
                    courseNameInput = courseName
                }
                if let courseID = courseID {
                    courseIDMapped = courseID
                }
            }
        }
    }
    
    private func submitReview() {
        isSubmitting = true
        errorMessage = ""
        
        Task {
            do {
                var uploadedPhotoUrls: [String] = existingPhotoUrls
                
                if let userId = session.currentUser?.id {
                    for image in capturedImages {
                        let url = try await reviewService.uploadPhoto(
                            image,
                            userId: userId
                        )
                        uploadedPhotoUrls.append(url)
                    }
                }
                
                if let existing = existingReview {
                    let updatedReview = Review(
                        id: existing.id, // non-optional now
                        userId: existing.userId,
                        username: username,
                        rating: rating,
                        comment: comment,
                        courseName: existing.courseName,
                        courseId: existing.courseId,
                        createdAt: existing.createdAt,
                        photoUrls: uploadedPhotoUrls.isEmpty ? nil : uploadedPhotoUrls
                    )
                    try await reviewService.updateReview(updatedReview)
                        
                } else {
                    let newReview = Review(
                        id: UUID(),
                        userId: session.currentUser?.id,
                        username: username,
                        rating: rating,
                        comment: comment,
                        courseName: courseName ?? courseNameInput,
                        courseId: courseID ?? courseIDMapped,
                        createdAt: date,
                        photoUrls: uploadedPhotoUrls.isEmpty ? nil : uploadedPhotoUrls
                    )
                    
                    try await reviewService.saveReview(newReview)
                }
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to submit review: \(error.localizedDescription)"
                    isSubmitting = false
                }
            }
        }
    }
}

struct CameraView: View {
    @Binding var capturedImages: [UIImage]
    @Binding var existingPhotoUrls: [String]
    @Environment(\.dismiss) var dismiss
    
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if !existingPhotoUrls.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(existingPhotoUrls.enumerated()), id: \.offset) { index, urlString in
                                ZStack(alignment: .topTrailing) {
                                    AsyncImage(url: URL(string: urlString)) { image in
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 100, height: 100)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    } placeholder: {
                                        ProgressView()
                                            .frame(width: 100,   height: 100)
                                    }
                                    
                                    Button(action: {
                                        existingPhotoUrls.remove(at: index)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.white)
                                            .background(Circle().fill(Color.black.opacity(0.6)))
                                    }
                                    .padding(4)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: 120)
                }
                
                
                if !capturedImages.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(capturedImages.enumerated()), id: \.offset) { index, image in
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    
                                    Button(action: {
                                        capturedImages.remove(at: index)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.white)
                                            .background(Circle().fill(Color.black.opacity(0.6)))
                                    }
                                    .padding(4)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: 120)
                }
                
                Button {
                    showCamera = true
                } label: {
                    HStack {
                        Image(systemName: "camera.fill")
                        Text("Take photo")
                        Spacer()
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.borderedProminent)
                
                Button {
                    showPhotoLibrary = true
                } label: {
                    HStack {
                        Image(systemName: "photo")
                        Text("Upload photo")
                        Spacer()
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.borderedProminent)
                
                if !capturedImages.isEmpty || !existingPhotoUrls.isEmpty {
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .sheet(isPresented: $showCamera) {
            CameraSelect(images: $capturedImages, sourceType: .camera)
                .ignoresSafeArea()
        }
        .presentationDetents([.medium, .large])
        .sheet(isPresented: $showPhotoLibrary) {
            CameraSelect(images: $capturedImages, sourceType: .photoLibrary)
                .ignoresSafeArea()
        }
    }
}

struct CameraSelect: UIViewControllerRepresentable {
    @Environment(\.dismiss) var dismiss
    @Binding var images: [UIImage]
    var sourceType: UIImagePickerController.SourceType
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.modalPresentationStyle = .fullScreen
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraSelect
        
        init(_ parent: CameraSelect) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let selectedImage = info[.originalImage] as? UIImage {
                parent.images.append(selectedImage)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
