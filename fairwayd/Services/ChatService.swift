//
//  ChatService.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 7/25/26.
//

import Combine
import CoreLocation
import Foundation
import Supabase


@MainActor
final class ChatService: ObservableObject {
    private let supabase = SupabaseManager.shared.client
    
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var isStreaming = false
    @Published private(set) var activeTool: String?
    @Published var errorText: String?
    
    private var streamTask: Task<Void, Never>?
    
    
    private func makeRequest(
        message: String,
        history: [HistoryEntry],
        skillLevel: SkillLevel?,
        location: CLLocation?
    ) async throws -> URLRequest {
        
        guard let url = URL(string: "\(APIConfig.supabaseURL)/functions/v1/chat-bot") else {
            throw URLError(.badURL)
        }
        let token = try await supabase.auth.session.accessToken
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // Space after Bearer is required
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        request.httpBody = try JSONEncoder().encode(
            ChatRequest(
                message: message,
                history: history,
                context: ChatContext(
                    skillLevel: skillLevel,
                    latitude: location?.coordinate.latitude,
                    longitude: location?.coordinate.longitude
                )
            )
        )
        return request
    }
    
    
    func send(_ text: String, skillLevel: SkillLevel?, location: CLLocation?) async {
          let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
          guard !trimmed.isEmpty, !isStreaming else { return }

          errorText = nil
        messages.append(ChatMessage(role: .user, text: trimmed))

          // History is everything before the message we just added — the edge function
          // appends that separately, wrapped with the context block.
          let history = messages.dropLast().suffix(20).map {
              HistoryEntry(role: $0.role.rawValue, content: $0.text)
          }

          // Empty placeholder the deltas stream into.
        messages.append(ChatMessage(role: .assistant, text: ""))
          let replyIndex = messages.count - 1

          isStreaming = true
          defer {
              isStreaming = false
              activeTool = nil
          }

          do {
              let request = try await makeRequest(
                  message: trimmed,
                  history: Array(history),
                  skillLevel: skillLevel,
                  location: location
              )

              let (bytes, response) = try await URLSession.shared.bytes(for: request)

              // An error response is plain JSON, not NDJSON — check before consuming.
              guard let http = response as? HTTPURLResponse else {
                  throw URLError(.badServerResponse)
              }
              guard http.statusCode == 200 else {
                  throw NSError(
                      domain: "ChatService",
                      code: http.statusCode,
                      userInfo: [NSLocalizedDescriptionKey: "Server returned \(http.statusCode)"]
                  )
              }

              let decoder = JSONDecoder()

              for try await line in bytes.lines {
                 
                  guard !line.isEmpty,
                        let data = line.data(using: .utf8),
                        let event = try? decoder.decode(StreamState.self, from: data)
                  else { continue }   // never let one bad line kill the stream

                  switch event.type {
                  case "text":
                      activeTool = nil
                      messages[replyIndex].text += event.text ?? ""

                  case "tool":
                      // Drop any pre-tool narration; the chip conveys it better.
                      activeTool = event.name
                      messages[replyIndex].text = ""

                  case "error":
                      errorText = event.message ?? "Something went wrong."

                  case "done":
                      break

                  default:
                      break
                  }
              }
              let count = messages[replyIndex].text.count
                print("stream ended: \(count) chars, errorText: \(errorText ?? "nil")")

              // Nothing streamed: don't leave an empty bubble sitting there.
              if messages[replyIndex].text.isEmpty {
                  messages.remove(at: replyIndex)
                  if errorText == nil {
                      errorText = "No response — please try again."
                  }
              }
          } catch is CancellationError {
              // User navigated away mid-stream. Not worth surfacing.
              if messages.indices.contains(replyIndex), messages[replyIndex].text.isEmpty {
                  messages.remove(at: replyIndex)
              }
          } catch {
              if messages.indices.contains(replyIndex) {
                  messages.remove(at: replyIndex)
              }
              errorText = error.localizedDescription
          }
      }
    
    func delete(id: String) {
        guard !isStreaming else { return }
        messages.removeAll { $0.id.uuidString == id }
    }
    
    func clear() {
        messages = []
        errorText = nil
        activeTool = nil
    }
    
    func cancel() {
        streamTask?.cancel()
    }
}
