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
    
    init(courseID: Int? = nil, courseName: String? = nil) {
        self.courseID = courseID
        self.courseName = courseName
        
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
    
    var body: some View {
        NavigationStack {
            Form {
                if accessMode == .accessedFromCreate {
                    Section(header: Text("Course Name")) {
                        TextField("Enter course name", text: $courseNameInput).bold()
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
                            List(courseSuggestions, id: \.id) { course in
                                Text(course.titleText)
                                    .onTapGesture {
                                        courseNameInput = course.titleText
                                        courseIDMapped = course.id
                                        courseSuggestions = []
                                    }
                            }
                            .frame(height: 150)
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
                        Label("Add photo", systemImage: "camera.fill")
                    }
                    
                    if !capturedImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(capturedImages, id: \.self) { image in
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 120, height: 90)
                                        .clipped()
                                        .cornerRadius(8)
                                }
                            }
                            .padding(.vertical, 4)
                        }
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
        .navigationTitle("Write Review")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }
            }
        }
    }
        .sheet(isPresented: $showCamera) {
            CameraView(capturedImages: $capturedImages)
        }
    }
    
    private func submitReview() {
        isSubmitting = true
        errorMessage = ""
        
        Task {
            do {
                var uploadedPhotoUrls: [String] = []
                
                if let userId = session.currentUser?.id {
                    for image in capturedImages {
                        let url = try await reviewService.uploadPhoto(image,
                                userId: userId
                        )
                        uploadedPhotoUrls.append(url)
                        }
                }
                
                let newReview = Review(
                    id: UUID(),
                    userId: session.currentUser?.id,
                    username: username,
                    rating: rating,
                    comment: comment,
                    courseName: courseName ?? courseNameInput,
                    courseId: courseID,
                    createdAt: date,
                    photoUrls: uploadedPhotoUrls
                )
                
                try await reviewService.saveReview(newReview)
                
                await MainActor.run {
                    dismiss()
                }
            }catch {
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
    @Environment(\.dismiss) var dismiss
    
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack (spacing: 12) {
                        ForEach(capturedImages, id: \.self) { image in
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 150, height: 120)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            VStack(spacing: 16) {
                Button {
                    showCamera = true
                } label: {
                    HStack {
                        Image(systemName: "camera.fill")
                        Text("Take photo")
                        Spacer()
                    }
                    .padding()
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
                }
                .buttonStyle(.borderedProminent)
                
                if !capturedImages.isEmpty {
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .sheet(isPresented: $showCamera) {
            CameraSelect(images: $capturedImages, sourceType: .camera)
                .ignoresSafeArea()
        }
        .presentationDetents([.height(200)])
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



