//
//  ImageService.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 12/27/25.
//

import Foundation

final class ImageService {
    static let shared = ImageService()
    private let provider = GooglePlacesImageProvider()
    private var imageCache: [String: URL] = [:]
    private var placeIDCache: [String: String] = [:]
    
    private init() {}
    
    func fetchCourseImage(
        placeID: String?,
        name: String,
        location: String? = nil
    ) async -> URL? {
        let imageCacheKey = placeID ?? "\(name)-\(location ?? "")"
        
        // Check image cache first
        if let cached = imageCache[imageCacheKey] {
            return cached
        }
        
        // If we have a placeID, use it directly
        if let placeID = placeID, !placeID.isEmpty {
            return await fetchImageByPlaceID(placeID: placeID, cacheKey: imageCacheKey)
        }
        
        // Check placeID cache
        let placeIDCacheKey = "\(name)-\(location ?? "")"
        if let cachedPlaceID = placeIDCache[placeIDCacheKey] {
            return await fetchImageByPlaceID(placeID: cachedPlaceID, cacheKey: imageCacheKey)
        }
        
        // Lookup placeID and fetch image
        return await lookupPlaceIDAndFetchImage(
            name: name,
            location: location,
            imageCacheKey: imageCacheKey,
            placeIDCacheKey: placeIDCacheKey
        )
    }
    
    private func fetchImageByPlaceID(
        placeID: String,
        cacheKey: String
    ) async -> URL? {
        do {
            let url = try await provider.fetchImageURLByPlaceID(placeID: placeID)
            if let url = url {
                imageCache[cacheKey] = url
            }
            return url
        } catch {
            print("Error fetching image by placeID:", error)
            return nil
        }
    }
    
    private func lookupPlaceIDAndFetchImage(
        name: String,
        location: String?,
        imageCacheKey: String,
        placeIDCacheKey: String
    ) async -> URL? {
        do {
            // First try to get placeID
            if let placeID = try await provider.fetchPlaceID(
                courseName: name,
                location: location
            ) {
                placeIDCache[placeIDCacheKey] = placeID
                return await fetchImageByPlaceID(
                    placeID: placeID,
                    cacheKey: imageCacheKey
                )
            }
            
            // Fallback: fetch image directly by name
            return await fetchByName(
                name: name,
                location: location,
                cacheKey: imageCacheKey
            )
        } catch {
            print("Error looking up placeID:", error)
            return nil
        }
    }
    
    private func fetchByName(
        name: String,
        location: String?,
        cacheKey: String
    ) async -> URL? {
        do {
            let url = try await provider.fetchImageURL(
                courseName: name,
                location: location
            )
            if let url = url {
                imageCache[cacheKey] = url
            }
            return url
        } catch {
            print("Error fetching image by name:", error)
            return nil
        }
    }
}
