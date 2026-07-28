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
                    .liquidGlassSurface()
                
                SecureField("Password", text: $password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .padding()
                    .liquidGlassSurface()
                
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
                    } else {
                        Text("Log In")
                            .font(.headline)
                        
                    }
                }
                .liquidGlass()
                .tint(.green)
                .disabled(session.isLoading)
                
                // or
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
                        Image("ios_dark_rd_SI")
            }
                .disabled(session.isLoading)
        }
        Spacer()
    }
        .padding()
}
}
#Preview {
    LoginView(mode: .constant(.login))
        .environmentObject(SessionStore())
}

