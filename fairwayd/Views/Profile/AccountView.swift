//
//  AccountView.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 12/17/25.
//

import SwiftUI

    struct AccountView: View {
        @EnvironmentObject var session: SessionStore
        @AppStorage("isDarkMode") private var isDarkMode: Bool?
        
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
                            .foregroundStyle(.green)
                    }
                }
                
                Section("Preferences") {
                    Toggle(isOn: Binding(
                        get: { isDarkMode ?? false },
                        set: { isDarkMode = $0 }
                    ).animation()) {
                        Label(isDarkMode == true ? "Dark Mode" : "Light Mode",
                              systemImage: isDarkMode == true ? "moon.fill" : "sun.max.fill")
                        .foregroundStyle(.green)
                    }
                    .tint(.green)
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
            .preferredColorScheme(isDarkMode == true ? .dark : isDarkMode == false ? .light : nil)

        }
    }

