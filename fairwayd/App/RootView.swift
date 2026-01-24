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
        ZStack {
            Group {
                if session.isAuthenticated {
                    if session.needsProfileSetup {
                        ProfileFormView(mode: session.isNewUser ? .setup: .edit)
                    }else {
                        MainView()
                    }
                } else {
                    ZStack {
                        switch mode {
                        case .landing:
                            AuthLandingView(mode: $mode)
                        case .login:
                            LoginView(mode: $mode)
                        case .signup:
                            SignupView(mode: $mode)
                        }
                    }
                    .animation(.easeInOut, value: mode)
                }
            }
        }
    }
}
