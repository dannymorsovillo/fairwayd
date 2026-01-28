//
//  SetGoogleUserNameView.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 1/25/26.
//

import SwiftUI

struct SetGoogleUserNameView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var username: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        VStack {
        Form {
            TextField("Enter username", text: $username)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            
            if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }

                Button {
                    saveUsername()
                } label: {
                    if isSaving {
                        HStack {
                            ProgressView()
                            Text("Saving…")
                        }
                    } else {
                        Text("Save")
                            .bold()
                    }
                }
                .disabled(isSaving || username.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding()
            }
        .navigationTitle("Set Username")
        .onAppear {
            username = session.currentUser?.username ?? ""
        }
        .onChange(of: session.needsUsername) { _, needsUsername in
            if !needsUsername {
                dismiss()
            }
        }
    }

    private func saveUsername() {
        isSaving = true
        errorMessage = nil

        Task {
            do {
                try await session.updateUsername(username)
                await MainActor.run {
                    isSaving = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }
}

