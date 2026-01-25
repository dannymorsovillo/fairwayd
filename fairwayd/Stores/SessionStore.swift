//
//  SessionStore.swift
//  fairwayd
//

import Foundation
import Supabase
import GoogleSignIn
import Combine

class SessionStore: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var needsProfileSetup = false
    @Published var isNewUser = false
    
    private let supabase = SupabaseManager.shared.client
    
    var engagementStore: EngagementStore?
    
    init() {
        Task {
            await checkSession()
            await observeAuthChanges()
        }
    }
    
    private func checkSession() async {
        do {
            let session = try await supabase.auth.session
           
            await MainActor.run {
                isAuthenticated = true
                isNewUser = false
                currentUser = User(
                    id: session.user.id,
                    email: session.user.email ?? "",
                    username: session.user.userMetadata["username"]?.stringValue
                )
            }
            await loadFullProfile()
            await checkProfileCompletion()
            await engagementStore?.setUser(session.user.id)
        } catch {
            print("checkSession failed: \(error)")
            await MainActor.run {
                isAuthenticated = false
                currentUser = nil
            }
        }
    }

    private func observeAuthChanges() async {
        await supabase.auth.onAuthStateChange { [weak self] event, session in
            Task { @MainActor in
                switch event {
                case .signedIn, .tokenRefreshed, .userUpdated, .mfaChallengeVerified:
                    if let session = session {
                        self?.isAuthenticated = true
                        self?.currentUser = User(
                            id: session.user.id,
                            email: session.user.email ?? "",
                            username: session.user.userMetadata["username"]?.stringValue
                        )
                        await self?.checkProfileCompletion()
                        await self?.engagementStore?.setUser(session.user.id)
                    }
                case .signedOut:
                    self?.isAuthenticated = false
                    self?.currentUser = nil
                    self?.needsProfileSetup = false
                    self?.engagementStore?.clearUser()
                case .passwordRecovery:
                    break
                case .userDeleted:
                    self?.isAuthenticated = false
                    self?.currentUser = nil
                    self?.needsProfileSetup = false
                    self?.engagementStore?.clearUser()
                case .initialSession:
                    if let session = session {
                        self?.isAuthenticated = true
                        self?.currentUser = User(
                            id: session.user.id,
                            email: session.user.email ?? "",
                            username: session.user.userMetadata["username"]?.stringValue
                        )
                        await self?.checkProfileCompletion()
                        await self?.engagementStore?.setUser(session.user.id)
                    } else {
                        self?.isAuthenticated = false
                        self?.currentUser = nil
                        self?.needsProfileSetup = false
                        self?.engagementStore?.clearUser()
                    }
                @unknown default:
                    break
                }
            }
        }
    }
    
    private func loadFullProfile() async {
        do {
            let userId = try await supabase.auth.session.user.id
            
            struct ProfileData: Codable {
                let skill_level: String?
                let home_course: String?
                let city: String?
                let state: String?
            }
            
            let profile: ProfileData = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            
            await MainActor.run {
                var skillLevel: SkillLevel? = nil
                if let skillLevelString = profile.skill_level {
                    skillLevel = SkillLevel(rawValue: skillLevelString)
                }
                
                currentUser = User(
                    id: userId,
                    email: currentUser?.email ?? "",
                    username: currentUser?.username,
                    skillLevel: skillLevel,
                    homeCourse: profile.home_course,
                    city: profile.city,
                    state: profile.state
                )
            }
        } catch {
            print("Failed to load full profile: \(error)")
        }
    }
    
    private func checkProfileCompletion() async {
        do {
            let userId = try await supabase.auth.session.user.id
            
            struct ProfileCheck: Codable {
                let skill_level: String?
                let home_course: String?
                let city: String?
                let state: String?
            }
            
            let profile: ProfileCheck = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            
            await MainActor.run {
                needsProfileSetup = profile.skill_level == nil ||
                                   profile.home_course == nil ||
                                   profile.city == nil ||
                                   profile.state == nil
            }
        } catch {
            await MainActor.run {
                needsProfileSetup = true
            }
        }
    }
    
    func signUp(email: String, password: String, confirmPassword: String, username: String? = nil) {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please fill in all fields"
            return
        }
        
        guard password == confirmPassword else {
            errorMessage = "Passwords don't match"
            return
        }
        
        guard password.count >= 8 else {
            errorMessage = "Password must be at least 8 characters"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                var metadata: [String: AnyJSON]? = nil
                if let username = username {
                    metadata = ["username": .string(username)]
                }
                
                let response = try await supabase.auth.signUp(
                    email: email,
                    password: password,
                    data: metadata
                )
                
                await MainActor.run {
                    isLoading = false
                    if let session = response.session {
                        isAuthenticated = true
                        needsProfileSetup = true
                        isNewUser = true
                        currentUser = User(
                            id: session.user.id,
                            email: session.user.email ?? "",
                            username: metadata?["username"]?.stringValue
                        )
                    } else {
                        errorMessage = "Please check your email to confirm your account"
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func signIn(email: String, password: String) {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please fill in all fields"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let response = try await supabase.auth.signIn(
                    email: email,
                    password: password
                )
                
                await MainActor.run {
                    isLoading = false
                    isAuthenticated = true
                    isNewUser = false
                    currentUser = User(
                        id: response.user.id,
                        email: response.user.email ?? "",
                        username: response.user.userMetadata["username"]?.stringValue
                    )
                }
                await checkProfileCompletion()
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func signOut() {
        Task {
            do {
                try await supabase.auth.signOut()
                await MainActor.run {
                    isAuthenticated = false
                    currentUser = nil
                    needsProfileSetup = false
                }
                engagementStore?.clearUser()
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func resetPassword(email: String) {
        guard !email.isEmpty else {
            errorMessage = "Please enter your email"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await supabase.auth.resetPasswordForEmail(email)
                
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Password reset email sent!"
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    
    func signInWithGoogle() {
        Task {
            isLoading = true
            errorMessage = nil
            
            do {
                guard let presentingViewController = getRootViewController() else {
                    throw URLError(.badURL)
                }
                
                let result = try await GIDSignIn.sharedInstance.signIn(
                    withPresenting: presentingViewController
                )
                
                guard let idToken = result.user.idToken?.tokenString else {
                    throw URLError(.badServerResponse)
                }
                
               try await supabase.auth.signInWithIdToken(
                    credentials: .init(
                        provider: .google,
                        idToken: idToken
                    )
                )
                
                await checkSession()
                
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    print("Google sign-in error:", error, (error as NSError).code, (error as NSError).domain)
                    isLoading = false
                }
            }
        }
    }

    @MainActor
    private func getRootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return nil
        }
        return rootViewController
    }

}

struct User {
    let id: UUID
    let email: String
    let username: String?
    var skillLevel: SkillLevel?
    var homeCourse: String?
    var city: String?
    var state: String?
}


// data according to WHS/USGA
enum SkillLevel: String, Codable, CaseIterable {
    case scratch = "Scratch (Elite)"
    case lowHandicap = "Low Handicap (Advanced)"
    case midHandicap = "Mid Handicap (Intermediate)"
    case highHandicap = "High Handicap (Beginner)"
    
    var description: String {
        switch self {
        case .scratch:
            return "Consistenly scoring par or better"
        case .lowHandicap:
            return "Scores in the 70s"
        case .midHandicap:
            return "Scores in the 80s-90s"
        case . highHandicap:
            return "Scores over 100"
            
        }
    }
    
    var handicapRange: String {
        switch self {
        case .scratch:
            return "Handicap: 0 or better"
        case .lowHandicap:
            return "Handicap: Under 10"
        case .midHandicap:
            return "Handicap: 10-29"
        case .highHandicap:
            return "Handicap: Above 29"
        }
    }
}

struct UserProfileData: Codable {
    let skillLevel: SkillLevel
    let homeCourse: String
    let city: String
    let state: String
}

