//
//  ProfileSetupView.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 12/28/25.
//

import SwiftUI
import Supabase


enum ProfileFormMode {
    case setup
    case edit
}

struct ProfileFormView: View {
    @EnvironmentObject var session: SessionStore
    
    let mode: ProfileFormMode
    
    @State private var selectedSkillLevel: SkillLevel = .midHandicap
    @State private var isLoading = false
    @State private var isLoadingProfile = false
    @State private var errorMessage: String?
    
    private let supabase = SupabaseManager.shared.client
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(mode == .setup ? "Complete Your Profile" : "Edit Profile")
                            .font(.largeTitle)
                            .bold()
                        
                        Text(mode == .setup ? "Help us personalize your experience" : "Update your profile details")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // Skill Level
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Skill Level")
                            .font(.headline)
                        
                        ForEach(SkillLevel.allCases, id: \.self) { level in
                            Button {
                                selectedSkillLevel = level
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(level.rawValue)
                                            .font(.subheadline)
                                            .bold()
                                            .foregroundColor(.primary)
                                        Text(level.description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(level.handicapRange)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if selectedSkillLevel == level {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                                .padding()
                                .background(
                                    selectedSkillLevel == level ?
                                    Color.green.opacity(0.1) :
                                    Color(.systemGray6)
                                )
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    Button {
                        saveProfile()
                    } label: {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text(mode == .setup ? "Continue" : "Save Changes")
                                .bold()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(isLoading)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
   func loadProfile() async {
        isLoadingProfile = true
        
        do {
            let userId = try await supabase.auth.session.user.id
            
            struct ProfileData: Codable {
                let skill_level: String?
            }
            
            let profile: ProfileData = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            
            await MainActor.run {
                if let skillLevelString = profile.skill_level,
                   let skillLevel = SkillLevel(rawValue: skillLevelString) {
                    self.selectedSkillLevel = skillLevel
                }
                isLoadingProfile = false
            }
        }
        catch {
            await MainActor.run {
                errorMessage = "Failed to load profile: \(error.localizedDescription)"
                isLoadingProfile = false
            }
        }
    }
    
    private func saveProfile() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let userId = try await supabase.auth.session.user.id
                
                try await supabase
                    .from("profiles")
                    .update([
                        "skill_level": selectedSkillLevel.rawValue,
                        "updated_at": ISO8601DateFormatter().string(from: Date())
                    ])
                    .eq("id", value: userId.uuidString)
                    .execute()
                
                await MainActor.run {
                    session.currentUser = User(
                        id: session.currentUser?.id ?? UUID(),
                        email: session.currentUser?.email ?? "",
                        username: session.currentUser?.username,
                        skillLevel: selectedSkillLevel,
                        homeCourse: nil,
                        city: nil,
                        state: nil
                    )
                    
                    isLoading = false
                    session.needsProfileSetup = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

