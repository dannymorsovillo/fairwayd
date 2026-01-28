//
//  ImageCache.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 1/27/26.
//

import SwiftUI
import UIKit

//Simple Image Caching for Reviews Views
final class ImageCache {
    static let shared = NSCache<NSURL, UIImage>()
    
    init() {
        ImageCache.shared.countLimit = 100
        ImageCache.shared.totalCostLimit = 50
    }
}


struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL
    let scale: CGFloat
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @State private var cachedImage: UIImage?
    
    init(
        url: URL,
        scale: CGFloat = 1.0,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.scale = scale
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let cachedImage {
                content(Image(uiImage: cachedImage))
            } else {
                AsyncImage(url: url, scale: scale) { phase -> AnyView in
                    switch phase {
                    case .success(let image):
                        saveToCache(from: url)
                        return AnyView(content(image))
                    case .failure(_):
                        return AnyView(placeholder())
                    case .empty:
                        return AnyView(placeholder())
                    @unknown default:
                        return AnyView(placeholder())
                    }
                }
            }
        }
        .onAppear{
            loadFromCache()
        }
    }
    
    private func loadFromCache() {
        if let cached = ImageCache.shared.object(forKey: url as NSURL) {
            cachedImage = cached
        }
    }
    
    private func saveToCache(from url: URL) {
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        ImageCache.shared.setObject(uiImage, forKey: url as NSURL)
                        if cachedImage == nil {
                            cachedImage = uiImage
                        }
                    }
                }
            } catch {
                print("Image caching failed: \(error)")
            }
        }
    }
}

