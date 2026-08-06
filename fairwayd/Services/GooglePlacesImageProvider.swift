//
//  GooglePlacesImageProvider.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 12/27/25.
//

import Foundation
import Supabase


final class GooglePlacesImageProvider {
    private let supabase = SupabaseManager.shared.client
    
    func fetchPlaceID(
        courseName: String,
        location: String?
    ) async throws -> String? {
        let request = PlacesSearchRequest(
            action: "search",
            courseName: courseName,
            location: location
        )
        
        let bodyData = try JSONEncoder().encode(request)
        
        let response: PlacesSearchResponse = try await supabase.functions.invoke(
            "google-places-image",
            options: FunctionInvokeOptions(body: bodyData)
        )
        
        let exactMatch = response.results.first { result in
            result.name.lowercased().contains(courseName.lowercased())
        }
        
        return exactMatch?.place_id ?? response.results.first?.place_id
    }
    
    func fetchImageURLByPlaceID(placeID: String) async throws -> URL? {
        let request = PlacesPhotoRequest(
            action: "photo",
            placeId: placeID
        )
        
        let bodyData = try JSONEncoder().encode(request)
        
        let response: PhotoResponse = try await supabase.functions.invoke(
            "google-places-image",
            options: FunctionInvokeOptions(body: bodyData)
        )
        
        return URL(string: response.photoUrl)
    }
    
    func fetchImageURL(
        courseName: String,
        location: String? = nil
    ) async throws -> URL? {
        guard let placeID = try await fetchPlaceID(
            courseName: courseName,
            location: location
        ) else {
            return nil
        }
        
        return try await fetchImageURLByPlaceID(placeID: placeID)
    }
}
