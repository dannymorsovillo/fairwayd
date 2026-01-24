//
//  GooglePlacesImageProvider.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 12/27/25.
//

import Foundation
import Supabase

struct PlacePlacesSearchRequest: Codable {
    let action: String
    let courseName: String
    let location: String?
}

struct PlacePhotoRequest: Codable {
    let action: String
    let placeId: String
}

struct PlacesSearchResponse: Codable {
    let results: [PlaceResult]
}

struct PlaceResult: Codable {
    let name: String
    let place_id: String
}

struct PhotoResponse: Codable {
    let photoUrl: String
}

final class GooglePlacesImageProvider {
    
    private let supabase = SupabaseManager.shared.client
    
    func fetchPlaceID(
        courseName: String,
        location: String?,
        completion: @escaping (String?) -> Void
    ) {
        Task {
            do {
                let request = PlacePlacesSearchRequest(
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
                
                let placeID = exactMatch?.place_id ?? response.results.first?.place_id
                
                DispatchQueue.main.async {
                    completion(placeID)
                }
            } catch {
                print("Error fetching place ID:", error)
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    
    func fetchImageURLByPlaceID(
        placeID: String,
        completion: @escaping (URL?) -> Void
    ) {
        Task {
            do {
                let request = PlacePhotoRequest(
                    action: "photo",
                    placeId: placeID
                )
                
                let bodyData = try JSONEncoder().encode(request)
                
                let response: PhotoResponse = try await supabase.functions.invoke(
                    "google-places-image",
                    options: FunctionInvokeOptions(body: bodyData)
                )
                
                if let url = URL(string: response.photoUrl) {
                    DispatchQueue.main.async {
                        completion(url)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            } catch {
                print("Error fetching image by place ID:", error)
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    
    func fetchImageURL(
        courseName: String,
        location: String? = nil,
        completion: @escaping (URL?) -> Void
    ) {
        fetchPlaceID(courseName: courseName, location: location) { [weak self] placeID in
            guard let placeID = placeID else {
                completion(nil)
                return
            }
            
            self?.fetchImageURLByPlaceID(placeID: placeID, completion: completion)
        }
    }
}
