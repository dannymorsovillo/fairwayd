//
//  AuthLandingView.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 12/27/25.
//

import SwiftUI

/// Push destinations for the unauthenticated flow. No `.landing` case — the
/// landing screen is the stack's root, so "back" is a pop rather than a mode.
enum AuthRoute: Hashable {
    case login
    case signup
}

struct AuthLandingView: View {

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
                    NavigationLink(value: AuthRoute.login) {
                        Text("Log In")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .liquidGlass()
                    .tint(.black)

                    NavigationLink(value: AuthRoute.signup) {
                        Text("Sign Up")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .liquidGlass()
                    .tint(.black)
                }
                .padding(.horizontal, 40)
                
                Spacer()
            }
        }
        .ignoresSafeArea()
        .toolbar(.hidden, for: .navigationBar)
    }
}
#Preview {
    NavigationStack {
        AuthLandingView()
    }
}

