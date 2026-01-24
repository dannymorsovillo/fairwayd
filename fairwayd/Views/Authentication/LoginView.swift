//
//  LoginView.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 12/26/25.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var session: SessionStore
    @Binding var mode: AuthMode
    
    @State private var email = ""
    @State private var password = ""
    
    var body: some View {
            VStack(spacing: 20) {
                HStack {
                    Button("Back"){
                        withAnimation{
                            mode = .landing
                        }
                    }
                    .tint(.green)
                    Spacer()
                }
                
                
                Text("fairwayd")
                    .font(.largeTitle)
                    .bold()
                
                Text("Welcome back")
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
                    
                    SecureField("Password", text: $password)
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
                    
                    Button {
                        session.signIn(email: email, password: password)
                    } label: {
                        if session.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        } else {
                            Text("Log In")
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


