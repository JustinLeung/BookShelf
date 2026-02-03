import Foundation
import SwiftUI
import UIKit

actor ImageCacheService {
    static let shared = ImageCacheService()

    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private var memoryCache: [String: Data] = [:]
    private let maxMemoryCacheSize = 50

    private init() {
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cachesDirectory.appendingPathComponent("BookCovers", isDirectory: true)

        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    func getImage(for isbn: String) async -> Data? {
        // Check memory cache first
        if let data = memoryCache[isbn] {
            return data
        }

        // Check disk cache
        let fileURL = cacheDirectory.appendingPathComponent("\(isbn).jpg")
        if let data = try? Data(contentsOf: fileURL) {
            // Add to memory cache
            await addToMemoryCache(isbn: isbn, data: data)
            return data
        }

        return nil
    }

    func cacheImage(_ data: Data, for isbn: String) async {
        // Save to memory cache
        await addToMemoryCache(isbn: isbn, data: data)

        // Save to disk cache
        let fileURL = cacheDirectory.appendingPathComponent("\(isbn).jpg")
        try? data.write(to: fileURL)
    }

    private func addToMemoryCache(isbn: String, data: Data) async {
        if memoryCache.count >= maxMemoryCacheSize {
            // Remove oldest entry (simple FIFO)
            if let firstKey = memoryCache.keys.first {
                memoryCache.removeValue(forKey: firstKey)
            }
        }
        memoryCache[isbn] = data
    }

    func clearCache() async {
        memoryCache.removeAll()

        if let contents = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) {
            for file in contents {
                try? fileManager.removeItem(at: file)
            }
        }
    }

    func cacheSize() async -> Int64 {
        var totalSize: Int64 = 0

        if let contents = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            for file in contents {
                if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(size)
                }
            }
        }

        return totalSize
    }
}

// MARK: - Image Loading Helper

struct CachedAsyncImage: View {
    let isbn: String
    let coverURL: URL?

    @State private var imageData: Data?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let data = imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.gray.opacity(0.1))
            } else {
                Image(systemName: "book.closed.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.gray)
                    .padding()
                    .background(Color.gray.opacity(0.1))
            }
        }
        .task {
            await loadImage()
        }
    }

    private func loadImage() async {
        // Check cache first
        if let cached = await ImageCacheService.shared.getImage(for: isbn) {
            imageData = cached
            return
        }

        // Fetch from network
        guard let url = coverURL else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let data = try await BookAPIService.shared.fetchCoverImage(url: url)
            await ImageCacheService.shared.cacheImage(data, for: isbn)
            imageData = data
        } catch {
            // Image fetch failed, will show placeholder
        }
    }
}
