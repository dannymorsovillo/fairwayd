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
                                .foregroundStyle(.secondary)
                        }
                        
                        if let username = user.username {
                            HStack {
                                Text("Username")
                                Spacer()
                                Text(username)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                
                Section("Profile") {
                    if let user = session.currentUser {
                        
                        if let skillLevel = user.skillLevel {
                            HStack {
                                Text("Skill Level")
                                Spacer()
                                Text(skillLevel.rawValue)
                                    .foregroundStyle(.secondary)
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
                    )) {
                        Label(isDarkMode == true ? "Dark Mode" : "Light Mode",
                              systemImage: isDarkMode == true ? "moon.fill" : "sun.max.fill")
                        .foregroundStyle(.green)
                    }
                    .liquidGlass()
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
                        .liquidGlass()
                    }
                }
            }
            .navigationTitle("Account")
            .preferredColorScheme(isDarkMode == true ? .dark : isDarkMode == false ? .light : nil)

        }
    }

