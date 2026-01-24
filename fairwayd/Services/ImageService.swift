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
        location: String? = nil,
        completion: @escaping (URL?) -> Void
    ) {
        let imageCacheKey = placeID ?? "\(name)-\(location ?? "")"
        
        if let cached = imageCache[imageCacheKey] {
            completion(cached)
            return
        }
        
        if let placeID = placeID, !placeID.isEmpty {
            fetchImageByPlaceID(placeID: placeID, cacheKey: imageCacheKey, completion: completion)
        } else {
            let placeIDCacheKey = "\(name)-\(location ?? "")"
            if let cachedPlaceID = placeIDCache[placeIDCacheKey] {
                fetchImageByPlaceID(placeID: cachedPlaceID, cacheKey: imageCacheKey, completion: completion)
            } else {
                lookupPlaceIDAndFetchImage(
                    name: name,
                    location: location,
                    imageCacheKey: imageCacheKey,
                    placeIDCacheKey: placeIDCacheKey,
                    completion: completion
                )
            }
        }
    }
    
    private func fetchImageByPlaceID(
        placeID: String,
        cacheKey: String,
        completion: @escaping (URL?) -> Void
    ) {
        provider.fetchImageURLByPlaceID(placeID: placeID) { [weak self] url in
            if let url = url {
                self?.imageCache[cacheKey] = url
            }
            DispatchQueue.main.async {
                completion(url)
            }
        }
    }
    
    private func lookupPlaceIDAndFetchImage(
        name: String,
        location: String?,
        imageCacheKey: String,
        placeIDCacheKey: String,
        completion: @escaping (URL?) -> Void
    ) {
        provider.fetchPlaceID(courseName: name, location: location) { [weak self] placeID in
            if let placeID = placeID {
                self?.placeIDCache[placeIDCacheKey] = placeID
                self?.fetchImageByPlaceID(placeID: placeID, cacheKey: imageCacheKey, completion: completion)
            } else {
                self?.fetchByName(name: name, location: location, cacheKey: imageCacheKey, completion: completion)
            }
        }
    }
    
    private func fetchByName(
        name: String,
        location: String?,
        cacheKey: String,
        completion: @escaping (URL?) -> Void
    ) {
        provider.fetchImageURL(courseName: name, location: location) { [weak self] url in
            if let url = url {
                self?.imageCache[cacheKey] = url
            }
            DispatchQueue.main.async {
                completion(url)
            }
        }
    }
}
