//
//  ImageCache.swift
//  fairwayd
//
//  Created by Danny Morsovillo on 1/27/26.
//

import SwiftUI


final class ImageCache {
    static let shared = ImageCache()
    
    private let cache = NSCache<NSURL, UIImage>()
    
    private init() {
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }
    
    func get(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }
    
    func set(_ image: UIImage, for url: URL) {
        let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }
}


struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder
    
    @State private var cachedImage: UIImage?
    @State private var isLoading = false
    @State private var hasFailed = false
    
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let cachedImage {
                content(Image(uiImage: cachedImage))
            } else if hasFailed {
                placeholder()
            } else {
                placeholder()
                    .onAppear { loadImage() }
            }
        }
    }
    
    private func loadImage() {
        guard let url, !isLoading else { return }
        
        if let cached = ImageCache.shared.get(for: url) {
            cachedImage = cached
            return
        }
        
        isLoading = true
        
        Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200,
                      let image = UIImage(data: data) else {
                    await MainActor.run { hasFailed = true; isLoading = false }
                    return
                }
                
                ImageCache.shared.set(image, for: url)
                
                await MainActor.run {
                    cachedImage = image
                    isLoading = false
                }
            } catch {
                await MainActor.run { hasFailed = true; isLoading = false }
            }
        }
    }
}
