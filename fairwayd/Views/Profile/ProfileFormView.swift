//
//  ProfileSetupView.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 12/28/25.
//

import SwiftUI
import Supabase

struct USState {
    let name: String
    let code: String
}

struct USStates {
    static let allStates: [USState] = [
        USState(name: "Alabama", code: "AL"),
        USState(name: "Alaska", code: "AK"),
        USState(name: "Arizona", code: "AZ"),
        USState(name: "Arkansas", code: "AR"),
        USState(name: "California", code: "CA"),
        USState(name: "Colorado", code: "CO"),
        USState(name: "Connecticut", code: "CT"),
        USState(name: "Delaware", code: "DE"),
        USState(name: "Florida", code: "FL"),
        USState(name: "Georgia", code: "GA"),
        USState(name: "Hawaii", code: "HI"),
        USState(name: "Idaho", code: "ID"),
        USState(name: "Illinois", code: "IL"),
        USState(name: "Indiana", code: "IN"),
        USState(name: "Iowa", code: "IA"),
        USState(name: "Kansas", code: "KS"),
        USState(name: "Kentucky", code: "KY"),
        USState(name: "Louisiana", code: "LA"),
        USState(name: "Maine", code: "ME"),
        USState(name: "Maryland", code: "MD"),
        USState(name: "Massachusetts", code: "MA"),
        USState(name: "Michigan", code: "MI"),
        USState(name: "Minnesota", code: "MN"),
        USState(name: "Mississippi", code: "MS"),
        USState(name: "Missouri", code: "MO"),
        USState(name: "Montana", code: "MT"),
        USState(name: "Nebraska", code: "NE"),
        USState(name: "Nevada", code: "NV"),
        USState(name: "New Hampshire", code: "NH"),
        USState(name: "New Jersey", code: "NJ"),
        USState(name: "New Mexico", code: "NM"),
        USState(name: "New York", code: "NY"),
        USState(name: "North Carolina", code: "NC"),
        USState(name: "North Dakota", code: "ND"),
        USState(name: "Ohio", code: "OH"),
        USState(name: "Oklahoma", code: "OK"),
        USState(name: "Oregon", code: "OR"),
        USState(name: "Pennsylvania", code: "PA"),
        USState(name: "Rhode Island", code: "RI"),
        USState(name: "South Carolina", code: "SC"),
        USState(name: "South Dakota", code: "SD"),
        USState(name: "Tennessee", code: "TN"),
        USState(name: "Texas", code: "TX"),
        USState(name: "Utah", code: "UT"),
        USState(name: "Vermont", code: "VT"),
        USState(name: "Virginia", code: "VA"),
        USState(name: "Washington", code: "WA"),
        USState(name: "West Virginia", code: "WV"),
        USState(name: "Wisconsin", code: "WI"),
        USState(name: "Wyoming", code: "WY")
    ]
}

enum ProfileFormMode {
    case setup
    case edit
}

struct ProfileFormView: View {
    @EnvironmentObject var session: SessionStore
    
    let mode: ProfileFormMode
    
    @State private var selectedSkillLevel: SkillLevel = .midHandicap
    @State private var homeCourse = ""
    @State private var city = ""
    @State private var state = ""
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
                        Text(mode == .setup ? "Complete Your Profile": "Edit Profile")
                            .font(.largeTitle)
                            .bold()
                        
                        Text(mode == .setup ? "Help us personalize your experience": "Update your profile details")
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
                    
                    // Home Course
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Home Course")
                            .font(.headline)
                        
                        TextField("e.g., Pebble Beach Golf Links", text: $homeCourse)
                            .textInputAutocapitalization(.words)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }
                    
                    // Location
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location")
                            .font(.headline)
                        
                        HStack(spacing: 12) {
                            TextField("City", text: $city)
                                .textInputAutocapitalization(.words)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                            
                            // State Picker/Dropdown
                            Menu {
                                ForEach(USStates.allStates, id: \.code) { state in
                                    Button(state.name) {
                                        self.state = state.code
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(state.isEmpty ? "State" : state)
                                        .foregroundColor(state.isEmpty ? .secondary : .primary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                                .frame(width: 100)
                            }
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
                            Text(mode == .setup ? "Continue" :"Save Changes")
                                .bold()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isFormValid ? Color.green : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(!isFormValid || isLoading)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var isFormValid: Bool {
        !homeCourse.isEmpty && !city.isEmpty && !state.isEmpty
    }
    
   func loadProfile() async {
        isLoadingProfile = true
        
        do {
            let userId = try await supabase.auth.session.user.id
            
            struct ProfileData: Codable {
                let skill_level: String?
                let home_course: String?
                let city: String?
                let state: String?
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
            }
            
            homeCourse = profile.home_course ?? ""
            city = profile.city ?? ""
            state = profile.state ?? ""
            isLoadingProfile = false
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
                        "home_course": homeCourse,
                        "city": city,
                        "state": state.uppercased(),
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
                        homeCourse: homeCourse,
                        city: city,
                        state: state.uppercased()
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
