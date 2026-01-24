//
//  EngagementStore.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 12/17/25.
//

import Foundation
import Combine
import Supabase

struct CourseSnapshot: Identifiable, Codable {
    let id: Int
    let title: String
    let subtitle: String
    let placeId: String?
    let location: String?
    var userId: UUID?
    
    enum CodingKeys: String, CodingKey {
        case id = "course_id"
        case title = "course_title"
        case subtitle = "course_subtitle"
        case placeId = "place_id"
        case location
        case userId = "user_id"
    }
}

final class EngagementStore: ObservableObject {
    @Published var favorites: [Int] = []
    @Published var snapshots: [Int: CourseSnapshot] = [:]
    @Published var isLoading = false
    
    
    private let supabase = SupabaseManager.shared.client
    private var userId: UUID?
    
    init() {}
    
    func setUser(_ userId: UUID) async {
        self.userId = userId
        await loadFavorites()
    }
    
    func clearUser() {
        self.userId = nil
        favorites = []
        snapshots = [:]
    }
    
    func isFavorite(_ id: Int) -> Bool {
        favorites.contains(id)
    }
    
    func toggleFavorite(_ id: Int) async {
        guard userId != nil else { return }
        
        if favorites.contains(id) {
            await removeFavorite(id)
        } else {
            if let snapshot = snapshots[id] {
                await addFavorite(snapshot)
            }
        }
    }
    
    func saveSnapshot(id: Int, title: String, subtitle: String, placeId: String?, location: String?, userId: UUID?) {
        let snap = CourseSnapshot(
            id: id,
            title: title,
            subtitle: subtitle,
            placeId: placeId,
            location: location,
            userId: nil
        )
        snapshots[id] = snap
    }
    
    func loadFavorites() async {
        guard let userId = userId else { return }
        
        await MainActor.run { isLoading = true }
        defer { Task { await MainActor.run { isLoading = false } } }
        
        do {
            let response = try await supabase
                .from("user_favorites")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
            
            let fetchedFavs = try JSONDecoder().decode([CourseSnapshot].self, from: response.data)
            
            await MainActor.run {
                self.favorites = fetchedFavs.map { $0.id }
                self.snapshots = fetchedFavs.reduce(into: [:]) { dict, snap in
                    dict[snap.id] = snap
                }
            }
        } catch {
            print("Error loading favorites: \(error.localizedDescription)")
        }
    }
    
    private func addFavorite(_ snapshot: CourseSnapshot) async {
        guard let userId = userId else { return }
        
        var favorite = snapshot
        favorite.userId = userId
        
        do {
            try await supabase
                .from("user_favorites")
                .insert(favorite)
                .execute()
            
            await MainActor.run {
                if !self.favorites.contains(snapshot.id) {
                    self.favorites.append(snapshot.id)
                }
            }
        } catch {
            print("Error adding favorite: \(error.localizedDescription)")
        }
    }
    
    private func removeFavorite(_ id: Int) async {
        guard let userId = userId else { return }
        
        do {
            try await supabase
                .from("user_favorites")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .eq("course_id", value: id)
                .execute()
            
            await MainActor.run {
                self.favorites.removeAll(where: { $0 == id })
            }
        } catch {
            print("Error removing favorite: \(error.localizedDescription)")
        }
    }
}
