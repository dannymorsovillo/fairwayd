//
//  BatchProcessor.swift
//  fairwayd
//

// CLAUDE GENERATED CODE REVIEW WHEN U CAN

import Foundation

/// A utility for processing items in controlled batches with concurrency limits
struct BatchProcessor {
    
    /// Configuration for batch processing
   nonisolated struct Config {
        var batchSize: Int = 10
        var maxConcurrent: Int = 5
        var delayBetweenBatches: UInt64 = 200_000_000 // 200ms in nanoseconds
        
        static let `default` = Config()
        
        static let conservative = Config(
            batchSize: 5,
            maxConcurrent: 3,
            delayBetweenBatches: 300_000_000
        )
        
        static let aggressive = Config(
            batchSize: 15,
            maxConcurrent: 8,
            delayBetweenBatches: 100_000_000
        )
    }
    
    /// Process items in batches with controlled concurrency
    /// - Parameters:
    ///   - items: The items to process
    ///   - config: Batch processing configuration
    ///   - onProgress: Optional callback for progress updates (0.0 to 1.0)
    ///   - transform: Async transform function for each item
    /// - Returns: Array of non-nil transformed results
    static func process<T, R>(
        items: [T],
        config: Config = .default,
        onProgress: ((Double) -> Void)? = nil,
        transform: @escaping (T) async -> R?
    ) async throws -> [R] {
        guard !items.isEmpty else {
            onProgress?(1.0)
            return []
        }
        
        var allResults: [R] = []
        let batches = items.chunked(into: config.batchSize)
        
        for (batchIndex, batch) in batches.enumerated() {
            try Task.checkCancellation()
            
            let batchResults = await processBatch(
                batch,
                maxConcurrent: config.maxConcurrent,
                transform: transform
            )
            allResults.append(contentsOf: batchResults)
            
            // Report progress
            let progress = Double(batchIndex + 1) / Double(batches.count)
            onProgress?(progress)
            
            // Delay between batches (skip after last batch)
            if batchIndex < batches.count - 1 {
                try await Task.sleep(nanoseconds: config.delayBetweenBatches)
            }
        }
        
        return allResults
    }
    
    /// Process items in batches, returning results paired with original items
    static func processWithInput<T, R>(
        items: [T],
        config: Config = .default,
        onProgress: ((Double) -> Void)? = nil,
        transform: @escaping (T) async -> R?
    ) async throws -> [(input: T, result: R)] {
        guard !items.isEmpty else {
            onProgress?(1.0)
            return []
        }
        
        var allResults: [(T, R)] = []
        let batches = items.chunked(into: config.batchSize)
        
        for (batchIndex, batch) in batches.enumerated() {
            try Task.checkCancellation()
            
            let batchResults = await processBatchWithInput(
                batch,
                maxConcurrent: config.maxConcurrent,
                transform: transform
            )
            allResults.append(contentsOf: batchResults)
            
            let progress = Double(batchIndex + 1) / Double(batches.count)
            onProgress?(progress)
            
            if batchIndex < batches.count - 1 {
                try await Task.sleep(nanoseconds: config.delayBetweenBatches)
            }
        }
        
        return allResults
    }
    
    /// Process all items in parallel with no batching (use for enrichment, etc.)
    static func processParallel<T, R>(
        items: [T],
        transform: @escaping (T) async -> R
    ) async -> [R] {
        await withTaskGroup(of: R.self) { group in
            for item in items {
                group.addTask {
                    await transform(item)
                }
            }
            
            var results: [R] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
    }
    
    /// Process all items in parallel, filtering out nil results
    static func processParallelCompact<T, R>(
        items: [T],
        transform: @escaping (T) async -> R?
    ) async -> [R] {
        await withTaskGroup(of: R?.self) { group in
            for item in items {
                group.addTask {
                    await transform(item)
                }
            }
            
            var results: [R] = []
            for await result in group {
                if let result { results.append(result) }
            }
            return results
        }
    }
    
    // MARK: - Private
    
    private static func processBatch<T, R>(
        _ batch: [T],
        maxConcurrent: Int,
        transform: @escaping (T) async -> R?
    ) async -> [R] {
        await withTaskGroup(of: R?.self) { group in
            var results: [R] = []
            var iterator = batch.makeIterator()
            
            // Seed initial tasks up to max concurrent limit
            for _ in 0..<min(maxConcurrent, batch.count) {
                if let item = iterator.next() {
                    group.addTask { await transform(item) }
                }
            }
            
            // As each task completes, add the next one
            for await result in group {
                if let result { results.append(result) }
                
                if let item = iterator.next() {
                    group.addTask { await transform(item) }
                }
            }
            
            return results
        }
    }
    
    private static func processBatchWithInput<T, R>(
        _ batch: [T],
        maxConcurrent: Int,
        transform: @escaping (T) async -> R?
    ) async -> [(T, R)] {
        await withTaskGroup(of: (T, R?).self) { group in
            var results: [(T, R)] = []
            var iterator = batch.makeIterator()
            
            for _ in 0..<min(maxConcurrent, batch.count) {
                if let item = iterator.next() {
                    group.addTask { (item, await transform(item)) }
                }
            }
            
            for await (input, result) in group {
                if let result { results.append((input, result)) }
                
                if let item = iterator.next() {
                    group.addTask { (item, await transform(item)) }
                }
            }
            
            return results
        }
    }
}

// MARK: - Array Extension

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
