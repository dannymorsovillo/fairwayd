//
//  GooglePlacesImageModel.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 8/6/26.
//

import Foundation

struct PlacesSearchRequest: Codable {
    let action: String
    let courseName: String
    let location: String?
}

struct PlacesPhotoRequest: Codable {
    let action: String
    let placeId: String
}

struct PlacesSearchResponse: Codable {
    let results: [PlacesResult]
}

struct PlacesResult: Codable {
    let name: String
    let place_id: String
}

struct PhotoResponse: Codable {
    let photoUrl: String
}
