//
//  AuthLandingView.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 12/27/25.
//

import SwiftUI

enum AuthMode {
    case landing
    case login
    case signup
}

struct AuthLandingView: View {
    @Binding var mode: AuthMode
    
    var body: some View {
        ZStack {
            Color.green
            
            VStack(spacing: 24) {
                Spacer()
                
                Text("fairwayd")
                    .font(.largeTitle)
                    .bold()
                    .foregroundColor(.white)
                
                Text("Find the course for you.")
                    .foregroundColor(.white.opacity(0.8))
                
               
                VStack(spacing: 16) {
                    Button {
                            mode = .login
                    } label: {
                        Text("Log In")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .foregroundColor(.green)
                    
                    Button {
                            mode = .signup
                    } label: {
                        Text("Sign Up")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .foregroundColor(.green)
                }
                .padding(.horizontal, 40)
                
                Spacer()
            }
        }
        .ignoresSafeArea()
    }
}


