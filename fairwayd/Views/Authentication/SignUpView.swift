//
//  SignUpView.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 12/27/25.
//
import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var session: SessionStore
    @Binding var mode: AuthMode

    @State private var email = ""
    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var homeCourse = ""
    @State private var location = ""
    @State private var handicapCategory = ""

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Button(action: {
                    mode = .landing
                    session.errorMessage = nil
                }) {
                        Image(systemName: "chevron.left")
                    }
                    .liquidGlass()
                    .tint(.green)
                    Spacer()
            }
            
            Text("fairwayd")
                .font(.title)
                .bold()
            
            Text("Sign Up")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(spacing: 16) {
                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .keyboardType(.emailAddress)
                    .padding()
                    .liquidGlass()
                
                TextField("Username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .padding()
                    .liquidGlass()
                
                SecureField("Password", text: $password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .padding()
                    .liquidGlass()
                
                SecureField("Confirm Password", text: $confirmPassword)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .padding()
                    .liquidGlass()
                
                if let errorMessage = session.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
                
                Button{
                    session.signUp(
                        email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                        password: password,
                        confirmPassword: confirmPassword,
                        username: username.isEmpty ? nil : username.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                } label: {
                    if session.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("Create Account")
                            .font(.headline)
                    }
                }
                .liquidGlass()
                .tint(.green)
                .disabled(session.isLoading)
                
                //or
                HStack {
                    VStack { Divider() }
                    Text("or")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                    VStack { Divider() }
                }
                .padding(.vertical, 8)
                
                
                Button {
                    session.signInWithGoogle()
                } label: {
                    Image("ios_dark_rd_SU")
                }
                .disabled(session.isLoading)
            }
            Spacer()
        }
        .padding()
    }
}
#Preview {
    SignUpView(mode: .constant(.signup))
        .environmentObject(SessionStore())
}
