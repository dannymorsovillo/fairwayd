//
//  ProfileSetupView.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 12/28/25.
//

import SwiftUI

enum ProfileFormMode {
    case setup
    case edit
}

struct ProfileFormView: View {
    @EnvironmentObject var session: SessionStore
    
    let mode: ProfileFormMode
    
    @State private var currentSkillLevel: SkillLevel?
    @State private var selectedSkillLevel: SkillLevel?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var highlightedSkillLevel: SkillLevel? {
        selectedSkillLevel ?? currentSkillLevel
    }

    var body: some View {
        // No navigation container here — both call sites supply one (RootView
        // wraps .setup, AccountView pushes .edit). Nesting one inside another
        // stacks two bars and pushes the title down.
        VStack(alignment: .leading, spacing: 16) {
            Text("Skill Level")
                .font(.headline)

            ForEach(SkillLevel.allCases, id: \.self) { level in
                Button {
                    selectedSkillLevel = level
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
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
                        if highlightedSkillLevel == level {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    .padding()
                    .background(
                        highlightedSkillLevel == level ?
                        Color.green.opacity(0.3) :
                        Color(.systemGray6)
                    )
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }

            if let errorMessage {
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
            .liquidGlass()
            .tint(.green)
            .disabled(isLoading)
        }
        .navigationTitle(mode == .setup ? "Create Profile" : "Edit Profile")
        .subTitleCreator(subTitle:  mode == .setup ? "Help us personalize your experience." : "Update your profile details")
        .padding()
        .task(id: session.currentUser?.skillLevel) {
            guard mode == .edit else { return }
            currentSkillLevel = session.currentUser?.skillLevel
        }
    }

    private func saveProfile() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // highlighted, not selected — saving without re-tapping should
                // keep the existing level rather than bail with the spinner
                // stuck on.
                guard let skillLevel = highlightedSkillLevel else {
                    await MainActor.run {
                        isLoading = false
                        errorMessage = "Pick a skill level to continue."
                    }
                    return
                }
                try await session.updateProfile(skillLevel: skillLevel)
                await MainActor.run {
                    isLoading = false
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

// Both previews supply the stack the real call sites do, so the title and
// subtitle render at the height they will in the app.
#Preview("Setup") {
    NavigationStack {
        ProfileFormView(mode: .setup)
    }
    .environmentObject(SessionStore())
}

#Preview("Edit") {
    NavigationStack {
        ProfileFormView(mode: .edit)
            .preferredColorScheme(.dark)
    }
    .environmentObject(SessionStore())
}
