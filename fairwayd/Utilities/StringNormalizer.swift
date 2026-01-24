//
//  StringNormalizer.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 1/16/26.
//
import Foundation

 nonisolated func normalizeCourseName(_ name: String) -> String {
    var result = name.lowercased()
    let removeWords = [" golf course", " golf club", " club", " at "]
    for word in removeWords {
        result = result.replacingOccurrences(of: word, with: " ")
    }
    result = result.components(separatedBy: CharacterSet.punctuationCharacters).joined(separator: " ")
    result = result.components(separatedBy: .whitespacesAndNewlines)
                   .filter { !$0.isEmpty }
                   .joined(separator: " ")
    return result
}
