//
//  RootView.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 12/26/25.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var session: SessionStore
    @State private var mode: AuthMode = .landing
    
    var body: some View {
        Group {
            if session.isAuthenticated {
                AuthenticatedView()
            } else {
                UnauthenticatedView(mode: $mode)
            }
        }
        .animation(.easeInOut, value: session.isAuthenticated)
    }
}

// MARK: - Authenticated View

private struct AuthenticatedView: View {
    @EnvironmentObject var session: SessionStore
    
    var body: some View {
        Group {
            if session.needsProfileSetup {
                NavigationStack {
                    ProfileFormView(mode: .setup)
                }
            } else {
                MainView()
            }
        }
        .sheet(isPresented: Binding(
            get: { session.isAuthenticated && session.needsProfileSetup && session.needsUsername },
            set: { _ in }
        )) {
            NavigationStack {
                SetGoogleUserNameView()
                    .interactiveDismissDisabled()
            }
        }
    }
}

// MARK: - Unauthenticated View

private struct UnauthenticatedView: View {
    @EnvironmentObject var session: SessionStore
    @Binding var mode: AuthMode
    
    var body: some View {
        ZStack {
            switch mode {
            case .landing:
                AuthLandingView(mode: $mode)
            case .login:
                LoginView(mode: $mode)
            case .signup:
                SignUpView(mode: $mode)
            }
        }
        .animation(.easeInOut, value: mode)
    }
}
