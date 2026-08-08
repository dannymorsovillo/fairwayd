//
//  ErrorService.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 8/7/26.
//

import Foundation

enum ErrorService: LocalizedError {
    case ApiError(Error)
    case DecodingError(Error)
    case notFound(String)
    
    var errorDescription: String? {
        switch self {
        case .ApiError: return "API request failed"
        case .DecodingError: return "Failed to decode response"
        case .notFound(let item): return "Couldn't find \(item)"
        }
    }
}
