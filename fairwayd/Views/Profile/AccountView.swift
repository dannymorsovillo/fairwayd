//
//  AccountView.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 12/17/25.
//

import SwiftUI

enum ColorMode {
    case light
    case dark
}
    struct AccountView: View {
        @EnvironmentObject var session: SessionStore
        @State private var curColorMode: ColorMode = .light
        
        var body: some View {
            Form {
                Section("Details") {
                    if let user = session.currentUser {
                        HStack {
                            Text("Email")
                            Spacer()
                            Text(user.email)
                                .foregroundColor(.secondary)
                        }
                        
                        if let username = user.username {
                            HStack {
                                Text("Username")
                                Spacer()
                                Text(username)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                
                Section("Profile") {
                    if let user = session.currentUser {
                        if let homeCourse = user.homeCourse {
                            HStack {
                                Text("Home Course")
                                Spacer()
                                Text(homeCourse)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let city = user.city, let state = user.state {
                            HStack {
                                Text("Location")
                                Spacer()
                                Text("\(city), \(state)")
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                        
                        if let skillLevel = user.skillLevel {
                            HStack {
                                Text("Skill Level")
                                Spacer()
                                Text(skillLevel.rawValue)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    NavigationLink {
                        ProfileFormView(mode: .edit)
                    } label: {
                        Label("Edit Profile", systemImage: "person.circle")
                    }
                }
                
                Section("Preferences") {
                    Button{
                        switch curColorMode {
                        case .light:
                            curColorMode = .dark
                        case .dark:
                            curColorMode = .light
                            
                        }
                    } label: {
                        HStack {
                            switch curColorMode {
                            case .light:
                                Image(systemName: "moon")
                                    .foregroundStyle(Color.green)
                                Text("Enable Dark Mode")
                                    .foregroundStyle(Color.primary)
                                    .preferredColorScheme(.light)
                            case .dark:
                                Image(systemName: "sun.max")
                                    .foregroundStyle(Color.green)
                                Text("Enable Light Mode")
                                    .foregroundStyle(Color.primary)
                                    .preferredColorScheme(.dark)
                            }
                            Spacer()
                        }
                    }
                    
                }
                Section {
                    Button(role: .destructive){
                        session.signOut()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Log out")
                            Spacer()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("Account")
        }
    }

