//
//  ChatBotView.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 7/25/26.
// _ text: String, skillLevel: SkillLevel?, location: CLLocation?

import SwiftUI
import ExyteChat


struct ChatBotView: View {
    @EnvironmentObject var chat: ChatService
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var locationManager: LocationManager
    
    private static let me = ExyteChat.User(
        id: "me",
        name: "You",
        avatarURL: nil,
        isCurrentUser: true
    )
    
    private static let assistant = ExyteChat.User(
        id: "agent",
        name: "fairwayd assistant",
        avatarURL: nil,
        isCurrentUser: false
    )
    
    
    private var exyteMessages: [Message] {
        chat.messages.map { message in
            Message(
                id: message.id.uuidString,
                user: message.role == .user ? Self.me: Self.assistant,
                text: message.text,
            )
        }
            
    }
    
    var body: some View {
        ChatView(messages: exyteMessages) { draft in
            Task {
                await chat.send(
                    draft.text,
                    skillLevel: session.currentUser?.skillLevel,
                    location: locationManager.location
                )
            }
        }
        .deleteMenuActionClosure(activeFor: { $0.user.isCurrentUser }) { message in
            chat.delete(id: message.id)
        }
        .navigationTitle("Fairwayd Assistant")
        .navigationBarTitleDisplayMode(.inline)
        .chatTheme(colors:.init(
            mainTint: .green,
            messageMyBG: .green,
            messageMyTimeText: .white,
            sendButtonBackground: .green
        ))
       // .liquidGlass()
        
    }
    
}

#Preview {
    // @EnvironmentObject traps at render time when missing, so every one the
    // view reads has to be supplied here — including those it only reads
    // indirectly through its own body.
    NavigationStack {
        ChatBotView()
    }
    .environmentObject(ChatService())
    .environmentObject(SessionStore())
    .environmentObject(LocationManager())
}
