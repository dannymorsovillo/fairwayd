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
    @Published var needsUsername = false
    
    private let supabase = SupabaseManager.shared.client
    var engagementStore: EngagementStore?
    
    init() {
        Task {
            await checkSession()
            await observeAuthChanges()
        }
    }
    
    // MARK: - Session Management
    private func checkSession() async {
        do {
            let session = try await supabase.auth.session
            await updateUserState(from: session)
        } catch {
            print("checkSession failed: \(error)")
             clearUserState()
        }
    }

    private func observeAuthChanges() async {
        await supabase.auth.onAuthStateChange { [weak self] event, session in
            guard let self else { return }
            
            Task { @MainActor in
                switch event {
                case .signedIn, .tokenRefreshed, .userUpdated, .initialSession:
                    if let session = session {
                        await self.updateUserState(from: session)
                    } else {
                        self.clearUserState()
                    }
                    
                case .signedOut, .userDeleted:
                     self.clearUserState()
                    
                case .passwordRecovery, .mfaChallengeVerified:
                    break
                    
                @unknown default:
                    break
                }
            }
        }
    }
    
    // MARK: - User State Management
    @MainActor
    private func updateUserState(from session: Session) async {
        let userId = session.user.id
        let email = session.user.email ?? ""
        let username = session.user.userMetadata["username"]?.stringValue
        
        let profileData = await loadProfile(userId: userId)
        
        // Update state
        currentUser = User(
            id: userId,
            email: email,
            username: username,
            skillLevel: profileData?.skillLevel,
        )
        
        isAuthenticated = true
        needsUsername = (username?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        needsProfileSetup = profileData?.skillLevel == nil
        
        await engagementStore?.setUser(userId)
    }
    
    @MainActor
    private func clearUserState() {
        isAuthenticated = false
        currentUser = nil
        needsProfileSetup = false
        needsUsername = false
        engagementStore?.clearUser()
    }
    
    // MARK: - Profile Loading
    private func loadProfile(userId: UUID) async -> ProfileData? {
        do {
            struct ProfileResponse: Codable {
                let skill_level: String?
            }
            
            let profile: ProfileResponse = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            
            return ProfileData(
                skillLevel: profile.skill_level.flatMap(SkillLevel.init),
            )
        } catch {
            print("Failed to load profile: \(error)")
            return nil
        }
    }
    
    // MARK: - Authentication Actions
    func signUp(email: String, password: String, confirmPassword: String, username: String? = nil) {
        // #region agent log
        let logData1: [String: Any] = [
            "sessionId": "debug-session",
            "runId": "run1",
            "hypothesisId": "B",
            "location": "SessionStore.swift:119",
            "message": "signUp function entry",
            "data": [
                "email": email,
                "emailLength": email.count,
                "emailBytes": Array(email.utf8),
                "emailIsEmpty": email.isEmpty,
                "passwordLength": password.count
            ],
            "timestamp": Int(Date().timeIntervalSince1970 * 1000)
        ]
        if let jsonData = try? JSONSerialization.data(withJSONObject: logData1),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            if let logFile = FileHandle(forWritingAtPath: "/Users/danny/Documents/fairwayd/.cursor/debug.log") {
                defer { try? logFile.close() }
                try? logFile.seekToEnd()
                try? logFile.write(contentsOf: (jsonString + "\n").data(using: .utf8)!)
            } else {
                try? (jsonString + "\n").write(toFile: "/Users/danny/Documents/fairwayd/.cursor/debug.log", atomically: true, encoding: .utf8)
            }
        }
        // #endregion

            guard validateSignUp(email: email, password: password, confirmPassword: confirmPassword) else {
                // #region agent log
                let logData2: [String: Any] = [
                    "sessionId": "debug-session",
                    "runId": "run1",
                    "hypothesisId": "E",
                    "location": "SessionStore.swift:121",
                    "message": "validateSignUp returned false",
                    "data": [
                        "errorMessage": errorMessage ?? "nil"
                    ],
                    "timestamp": Int(Date().timeIntervalSince1970 * 1000)
                ]
                if let jsonData = try? JSONSerialization.data(withJSONObject: logData2),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    if let logFile = FileHandle(forWritingAtPath: "/Users/danny/Documents/fairwayd/.cursor/debug.log") {
                        defer { try? logFile.close() }
                        try? logFile.seekToEnd()
                        try? logFile.write(contentsOf: (jsonString + "\n").data(using: .utf8)!)
                    } else {
                        try? (jsonString + "\n").write(toFile: "/Users/danny/Documents/fairwayd/.cursor/debug.log", atomically: true, encoding: .utf8)
                    }
                }
                // #endregion
                return
            }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // #region agent log
                let logData3: [String: Any] = [
                    "sessionId": "debug-session",
                    "runId": "run1",
                    "hypothesisId": "C",
                    "location": "SessionStore.swift:131",
                    "message": "Before Supabase signUp call",
                    "data": [
                        "email": email,
                        "emailLength": email.count,
                        "emailBytes": Array(email.utf8),
                        "emailLowercased": email.lowercased()
                    ],
                    "timestamp": Int(Date().timeIntervalSince1970 * 1000)
                ]
                if let jsonData = try? JSONSerialization.data(withJSONObject: logData3),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    if let logFile = FileHandle(forWritingAtPath: "/Users/danny/Documents/fairwayd/.cursor/debug.log") {
                        defer { try? logFile.close() }
                        try? logFile.seekToEnd()
                        try? logFile.write(contentsOf: (jsonString + "\n").data(using: .utf8)!)
                    } else {
                        try? (jsonString + "\n").write(toFile: "/Users/danny/Documents/fairwayd/.cursor/debug.log", atomically: true, encoding: .utf8)
                    }
                }
                // #endregion
                let metadata = username.map { ["username": AnyJSON.string($0)] }
                let response = try await supabase.auth.signUp(
                    email: email,
                    password: password,
                    data: metadata
                )
                
                // #region agent log
                let logData4: [String: Any] = [
                    "sessionId": "debug-session",
                    "runId": "run1",
                    "hypothesisId": "D",
                    "location": "SessionStore.swift:137",
                    "message": "Supabase signUp succeeded",
                    "data": [
                        "hasSession": response.session != nil
                    ],
                    "timestamp": Int(Date().timeIntervalSince1970 * 1000)
                ]
                if let jsonData = try? JSONSerialization.data(withJSONObject: logData4),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    if let logFile = FileHandle(forWritingAtPath: "/Users/danny/Documents/fairwayd/.cursor/debug.log") {
                        defer { try? logFile.close() }
                        try? logFile.seekToEnd()
                        try? logFile.write(contentsOf: (jsonString + "\n").data(using: .utf8)!)
                    } else {
                        try? (jsonString + "\n").write(toFile: "/Users/danny/Documents/fairwayd/.cursor/debug.log", atomically: true, encoding: .utf8)
                    }
                }
                // #endregion
                
                await MainActor.run {
                    isLoading = false
                    if response.session != nil {
                        // Auth state change will handle the rest
                    } else {
                        errorMessage = "Please check your email to confirm your account"
                    }
                }
            } catch {
                // #region agent log
                let errorDesc = error.localizedDescription
                let errorString = String(describing: error)
                let logData5: [String: Any] = [
                    "sessionId": "debug-session",
                    "runId": "run1",
                    "hypothesisId": "A",
                    "location": "SessionStore.swift:145",
                    "message": "Supabase signUp error",
                    "data": [
                        "errorLocalizedDescription": errorDesc,
                        "errorString": errorString,
                        "errorType": String(describing: type(of: error)),
                        "email": email,
                        "emailLength": email.count
                    ],
                    "timestamp": Int(Date().timeIntervalSince1970 * 1000)
                ]
                if let jsonData = try? JSONSerialization.data(withJSONObject: logData5),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    if let logFile = FileHandle(forWritingAtPath: "/Users/danny/Documents/fairwayd/.cursor/debug.log") {
                        defer { try? logFile.close() }
                        try? logFile.seekToEnd()
                        try? logFile.write(contentsOf: (jsonString + "\n").data(using: .utf8)!)
                    } else {
                        try? (jsonString + "\n").write(toFile: "/Users/danny/Documents/fairwayd/.cursor/debug.log", atomically: true, encoding: .utf8)
                    }
                }
                // #endregion
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
                _ = try await supabase.auth.signIn(email: email, password: password)
                await MainActor.run {
                    isLoading = false
                }
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
                // Auth listener will handle state clearing, but force it just in case
                 clearUserState()
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func signInWithGoogle() {
        Task {
            await MainActor.run {
                isLoading = true
                errorMessage = nil
            }
            
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
                    credentials: .init(provider: .google, idToken: idToken)
                )
                
                // Manually get the session and update state
                // The auth listener might not fire immediately
                let session = try await supabase.auth.session
                await updateUserState(from: session)
                
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func updateUsername(_ username: String) async throws {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ValidationError.emptyUsername
        }
        
        try await supabase.auth.update(user: .init(
            data: ["username": .string(trimmed)]
        ))
        
        // Force refresh to get updated metadata
        let session = try await supabase.auth.refreshSession()
        await updateUserState(from: session)
    }
    
    func updateProfile(skillLevel: SkillLevel) async throws {
        let userId = try await supabase.auth.session.user.id
        
        try await supabase
            .from("profiles")
            .update([
                "skill_level": skillLevel.rawValue,
                "updated_at": ISO8601DateFormatter().string(from: Date())
            ])
            .eq("id", value: userId.uuidString)
            .execute()
        
        // Reload the session to get updated profile
        let session = try await supabase.auth.session
        await updateUserState(from: session)
    }
    
    // MARK: - Helpers
    
    private func validateSignUp(email: String, password: String, confirmPassword: String) -> Bool {
        // #region agent log
        let logData: [String: Any] = [
            "sessionId": "debug-session",
            "runId": "run1",
            "hypothesisId": "D",
            "location": "SessionStore.swift:267",
            "message": "validateSignUp entry",
            "data": [
                "email": email,
                "emailLength": email.count,
                "emailIsEmpty": email.isEmpty,
                "passwordLength": password.count,
                "passwordIsEmpty": password.isEmpty
            ],
            "timestamp": Int(Date().timeIntervalSince1970 * 1000)
        ]
        if let jsonData = try? JSONSerialization.data(withJSONObject: logData),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            if let logFile = FileHandle(forWritingAtPath: "/Users/danny/Documents/fairwayd/.cursor/debug.log") {
                defer { try? logFile.close() }
                try? logFile.seekToEnd()
                try? logFile.write(contentsOf: (jsonString + "\n").data(using: .utf8)!)
            } else {
                try? (jsonString + "\n").write(toFile: "/Users/danny/Documents/fairwayd/.cursor/debug.log", atomically: true, encoding: .utf8)
            }
        }
        // #endregion
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please fill in all fields"
            return false
        }
        
        guard password == confirmPassword else {
            errorMessage = "Passwords don't match"
            return false
        }
        
        guard password.count >= 8 else {
            errorMessage = "Password must be at least 8 characters"
            return false
        }
        
        // #region agent log
        let logData2: [String: Any] = [
            "sessionId": "debug-session",
            "runId": "run1",
            "hypothesisId": "D",
            "location": "SessionStore.swift:283",
            "message": "validateSignUp returning true",
            "data": [:],
            "timestamp": Int(Date().timeIntervalSince1970 * 1000)
        ]
        if let jsonData = try? JSONSerialization.data(withJSONObject: logData2),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            if let logFile = FileHandle(forWritingAtPath: "/Users/danny/Documents/fairwayd/.cursor/debug.log") {
                defer { try? logFile.close() }
                try? logFile.seekToEnd()
                try? logFile.write(contentsOf: (jsonString + "\n").data(using: .utf8)!)
            } else {
                try? (jsonString + "\n").write(toFile: "/Users/danny/Documents/fairwayd/.cursor/debug.log", atomically: true, encoding: .utf8)
            }
        }
        // #endregion
        
        return true
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

// MARK: - Supporting Types

struct User {
    let id: UUID
    let email: String
    let username: String?
    var skillLevel: SkillLevel?
    var homeCourse: String?
    var city: String?
    var state: String?
}

struct ProfileData {
    let skillLevel: SkillLevel?
}

enum SkillLevel: String, Codable, CaseIterable {
    case scratch = "Scratch (Elite)"
    case lowHandicap = "Low Handicap (Advanced)"
    case midHandicap = "Mid Handicap (Intermediate)"
    case highHandicap = "High Handicap (Beginner)"
    
    var description: String {
        switch self {
        case .scratch: return "Consistently scoring par or better"
        case .lowHandicap: return "Scores in the 70s"
        case .midHandicap: return "Scores in the 80s-90s"
        case .highHandicap: return "Scores over 100"
        }
    }
    
    var handicapRange: String {
        switch self {
        case .scratch: return "Handicap: 0 or better"
        case .lowHandicap: return "Handicap: 1-9"
        case .midHandicap: return "Handicap: 10-18"
        case .highHandicap: return "Handicap: Above 19+"
        }
    }
}

enum ValidationError: LocalizedError {
    case emptyUsername
    
    var errorDescription: String? {
        switch self {
        case .emptyUsername: return "Username cannot be empty"
        }
    }
}

