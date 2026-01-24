//
//  SignUpView.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 12/27/25.
//
import SwiftUI

struct SignupView: View {
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
                Button("Back") {
                    withAnimation {
                        mode = .landing
                    }
                }
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
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                
                TextField("Username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                
                SecureField("Password", text: $password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                
                SecureField("Confirm Password", text: $confirmPassword)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                
                if let errorMessage = session.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                    
                }
                
                Button{
                    session.signUp(
                        email: email,
                        password: password,
                        confirmPassword: confirmPassword
                    )
                } label: {
                    if session.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    } else {
                        Text("Create Account")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(session.isLoading)
            }
            Spacer()
        }
        .padding()
    }
}


 
