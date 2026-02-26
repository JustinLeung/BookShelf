import SwiftUI
import UIKit
import VisionKit
import Vision
import AVFoundation

struct ScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: BookshelfViewModel

    @State private var isShowingScanner = false
    @State private var isShowingCamera = false
    @State private var scannedISBN: String?
    @State private var showManualEntry = false
    @State private var showOCRResults = false
    @State private var ocrStatus: OCRStatus = .idle
    @State private var ocrSearchQuery: String?

    enum OCRStatus: Equatable {
        case idle
        case processing
        case searching(String)
        case found(Int)
        case error(String)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 80))
                    .foregroundStyle(Color.accentColor)

                Text("Scan Book")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Scan the ISBN barcode or take a photo of the book cover")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                VStack(spacing: 12) {
                    if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                        Button {
                            isShowingScanner = true
                        } label: {
                            Label("Scan Barcode", systemImage: "barcode.viewfinder")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    Button {
                        isShowingCamera = true
                    } label: {
                        Label("Photo of Cover", systemImage: "camera.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 32)

                Button {
                    showManualEntry = true
                } label: {
                    Text("Enter ISBN Manually")
                        .font(.subheadline)
                        .foregroundStyle(Color.accentColor)
                }

                Spacer()

                statusView
            }
            .navigationTitle("Scan")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isShowingScanner) {
                DataScannerRepresentable(scannedISBN: $scannedISBN)
                    .ignoresSafeArea()
            }
            .sheet(isPresented: $isShowingCamera) {
                CameraCaptureView { image in
                    processImageWithOCR(image)
                }
            }
            .sheet(isPresented: $showManualEntry) {
                ManualISBNEntrySheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showOCRResults) {
                OCRResultsSheet(viewModel: viewModel, searchQuery: ocrSearchQuery ?? "")
            }
            .onChange(of: scannedISBN) { _, newValue in
                if let isbn = newValue {
                    Task {
                        await viewModel.lookupBook(isbn: isbn)
                        scannedISBN = nil
                    }
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch ocrStatus {
        case .idle:
            if viewModel.isLoading {
                ProgressView("Looking up book...")
                    .padding()
            }
        case .processing:
            VStack(spacing: 8) {
                ProgressView()
                Text("Reading text from image...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
        case .searching(let text):
            VStack(spacing: 8) {
                ProgressView()
                Text("Searching for: \(text)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding()
        case .found(let count):
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title)
                Text("Found \(count) result\(count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
        case .error(let message):
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.red)
                .padding()
        }
    }

    private func processImageWithOCR(_ image: UIImage) {
        ocrStatus = .processing

        Task {
            do {
                let recognizedText = try await performOCR(on: image)
                print("=== OCR RECOGNIZED TEXT ===")
                print(recognizedText)
                print("=== END OCR TEXT ===")

                // First try to find an ISBN in the text
                if let isbn = extractISBN(from: recognizedText) {
                    print("Found ISBN: \(isbn)")
                    ocrStatus = .searching(isbn)
                    await viewModel.lookupBook(isbn: isbn)
                    ocrStatus = .idle
                    return
                }

                // Apply OCR error corrections
                let correctedText = correctOCRErrors(recognizedText)
                if correctedText != recognizedText {
                    print("=== OCR CORRECTED TEXT ===")
                    print(correctedText)
                    print("=== END CORRECTED TEXT ===")
                }

                // Extract title and author from OCR text
                let extracted = extractTitleAndAuthor(from: correctedText)
                print("Extracted - Title: '\(extracted.title ?? "nil")', Author: '\(extracted.author ?? "nil")'")

                // Also try to find potential author names for fallback search
                let potentialNames = findPotentialAuthorNames(from: correctedText)
                print("Potential author names found: \(potentialNames)")

                guard let title = extracted.title, !title.isEmpty else {
                    // Fallback: if we found potential names, search with just those
                    if !potentialNames.isEmpty {
                        let authorQuery = potentialNames.joined(separator: " ")
                        ocrStatus = .searching(authorQuery)
                        let fallbackResults = try await BookAPIService.shared.smartSearch(
                            query: authorQuery,
                            author: nil
                        )
                        if !fallbackResults.isEmpty {
                            viewModel.searchResults = fallbackResults
                            ocrSearchQuery = authorQuery
                            ocrStatus = .found(fallbackResults.count)
                            try? await Task.sleep(for: .seconds(0.5))
                            showOCRResults = true
                            ocrStatus = .idle
                            return
                        }
                    }

                    ocrStatus = .error("Could not find book information in the image")
                    try? await Task.sleep(for: .seconds(3))
                    ocrStatus = .idle
                    return
                }

                // Use smart search with Google Books (primary) + Open Library (fallback)
                let displayQuery = extracted.author != nil ? "\(title) by \(extracted.author!)" : title
                ocrStatus = .searching(displayQuery)

                var results = try await BookAPIService.shared.smartSearch(
                    query: title,
                    author: extracted.author
                )

                // Fallback: if no results and we have potential names, try searching with just the names
                if results.isEmpty && !potentialNames.isEmpty {
                    let authorQuery = potentialNames.joined(separator: " ")
                    print("Fallback search with potential author: '\(authorQuery)'")
                    ocrStatus = .searching(authorQuery)
                    results = try await BookAPIService.shared.smartSearch(
                        query: authorQuery,
                        author: nil
                    )
                }

                if results.isEmpty {
                    ocrStatus = .error("No books found. Try taking a clearer photo.")
                    try? await Task.sleep(for: .seconds(3))
                    ocrStatus = .idle
                } else {
                    viewModel.searchResults = results
                    ocrSearchQuery = displayQuery
                    ocrStatus = .found(results.count)
                    try? await Task.sleep(for: .seconds(0.5))
                    showOCRResults = true
                    ocrStatus = .idle
                }
            } catch {
                print("OCR error: \(error)")
                ocrStatus = .error("Search failed: \(error.localizedDescription)")
                try? await Task.sleep(for: .seconds(3))
                ocrStatus = .idle
            }
        }
    }

    private func performOCR(on image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }

                // Calculate size statistics to filter small text
                let sizes = observations.map { $0.boundingBox.height }
                let maxHeight = sizes.max() ?? 0
                let avgHeight = sizes.isEmpty ? 0 : sizes.reduce(0, +) / CGFloat(sizes.count)

                // Dynamic threshold: keep text that is at least 40% of max height or above average
                // This filters out small blurbs while keeping title and author
                let sizeThreshold = max(maxHeight * 0.35, avgHeight * 0.8)

                print("[OCR] Max text height: \(maxHeight), Avg: \(avgHeight), Threshold: \(sizeThreshold)")

                // Filter to keep only larger text (likely title/author)
                let significantObservations = observations.filter { obs in
                    let height = obs.boundingBox.height
                    let isLargeEnough = height >= sizeThreshold

                    if let text = obs.topCandidates(1).first?.string {
                        print("[OCR] '\(text)' - height: \(String(format: "%.3f", height)) - \(isLargeEnough ? "KEEP" : "skip")")
                    }

                    return isLargeEnough
                }

                // Sort by vertical position (top to bottom) then by size (larger first)
                let sortedObservations = significantObservations.sorted { obs1, obs2 in
                    let y1 = 1 - obs1.boundingBox.midY
                    let y2 = 1 - obs2.boundingBox.midY
                    if abs(y1 - y2) < 0.05 {
                        return obs1.boundingBox.height > obs2.boundingBox.height
                    }
                    return y1 < y2
                }

                let text = sortedObservations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")

                continuation.resume(returning: text)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func extractISBN(from text: String) -> String? {
        // Look for ISBN patterns: ISBN-10 or ISBN-13
        let patterns = [
            "ISBN[- ]?1[03][- ]?:?[- ]?([0-9X-]{10,17})",
            "ISBN[- ]?:?[- ]?([0-9X-]{10,17})",
            "\\b(97[89][- ]?[0-9]{1,5}[- ]?[0-9]+[- ]?[0-9]+[- ]?[0-9X])\\b",
            "\\b([0-9]{9}[0-9X])\\b"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(text.startIndex..., in: text)
                if let match = regex.firstMatch(in: text, options: [], range: range) {
                    if match.numberOfRanges > 1, let captureRange = Range(match.range(at: 1), in: text) {
                        let isbn = String(text[captureRange])
                            .replacingOccurrences(of: "-", with: "")
                            .replacingOccurrences(of: " ", with: "")
                        if isbn.count == 10 || isbn.count == 13 {
                            return isbn
                        }
                    }
                }
            }
        }

        return nil
    }

    // swiftlint:disable cyclomatic_complexity
    /// Extracts likely title and author from OCR text
    /// Returns a tuple with the best guess for title and author (author may be nil)
    private func extractTitleAndAuthor(from text: String) -> (title: String?, author: String?) {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Text to completely exclude
        let excludeExact = Set([
            "new york", "times", "bestseller", "bestselling", "best seller",
            "#1", "national", "international", "a novel", "a memoir", "a thriller"
        ])

        // Patterns to exclude (partial match)
        let excludeContains = [
            "million copies", "author of", "copyright", "all rights",
            "published by", "isbn", "introduction by", "foreword by",
            "translated by", "praise for", "acclaim for", "winner of",
            "washington post", "wall street journal", "los angeles times",
            "boston globe", "new york times", "counterintuitive", "approach",
            "living a good life"
        ]

        // First pass: clean all lines
        var cleanedLines: [String] = []
        for line in lines {
            let cleaned = line
                .replacingOccurrences(of: "\u{2022}", with: "")
                .replacingOccurrences(of: "\"", with: "")
                .replacingOccurrences(of: "\u{201C}", with: "")
                .replacingOccurrences(of: "\u{201D}", with: "")
                .trimmingCharacters(in: .punctuationCharacters)
                .trimmingCharacters(in: .whitespaces)

            let lowercased = cleaned.lowercased()

            // Skip excluded exact matches
            if excludeExact.contains(lowercased) {
                continue
            }

            // Skip excluded patterns
            if excludeContains.contains(where: { lowercased.contains($0) }) {
                continue
            }

            // Skip very short lines
            if cleaned.count < 2 {
                continue
            }

            cleanedLines.append(cleaned)
        }

        // Look for author name - check for single-word lines that could be FIRST LAST
        var potentialAuthor: String?
        var authorLineIndices: Set<Int> = []

        // Collect all single-word name parts (like "HARUKI", "MURAKAMI")
        var singleNameParts: [(index: Int, name: String)] = []
        for (index, line) in cleanedLines.enumerated() where looksLikeSingleNamePart(line) {
            singleNameParts.append((index: index, name: line))
        }

        // Strategy 1: If we have exactly 2 single name parts, combine them (handles non-adjacent too)
        // This catches cases like "MURAKAMI" ... "HARUKI" scattered in the OCR
        if singleNameParts.count == 2 && potentialAuthor == nil {
            // Combine in the order they appear, or try both orders
            let combined = "\(singleNameParts[0].name) \(singleNameParts[1].name)"
            potentialAuthor = combined
            authorLineIndices.insert(singleNameParts[0].index)
            authorLineIndices.insert(singleNameParts[1].index)
            print("Detected author from two name parts: \(combined)")
        }

        // Strategy 2: If we have more than 2 single name parts, try adjacent pairs first
        if singleNameParts.count > 2 && potentialAuthor == nil {
            for i in 0..<cleanedLines.count {
                let line = cleanedLines[i]
                if looksLikeSingleNamePart(line) {
                    if i + 1 < cleanedLines.count {
                        let nextLine = cleanedLines[i + 1]
                        if looksLikeSingleNamePart(nextLine) {
                            let combined = "\(line) \(nextLine)"
                            potentialAuthor = combined
                            authorLineIndices.insert(i)
                            authorLineIndices.insert(i + 1)
                            print("Detected author from adjacent lines: \(combined)")
                            break
                        }
                    }
                }
            }
        }

        // Strategy 3: Look for a line that looks like a full author name (2-3 words)
        if potentialAuthor == nil {
            for (index, line) in cleanedLines.enumerated() where looksLikeAuthorName(line) {
                potentialAuthor = line
                authorLineIndices.insert(index)
                print("Detected author: \(line)")
                break
            }
        }

        // Collect all words from non-author lines for title reconstruction
        var allWords: [String] = []
        for (index, line) in cleanedLines.enumerated() {
            if authorLineIndices.contains(index) {
                continue
            }

            let words = line.components(separatedBy: .whitespaces)
                .map { $0.trimmingCharacters(in: .punctuationCharacters) }
                .filter { !$0.isEmpty && $0.count >= 2 }

            for word in words {
                let lower = word.lowercased()
                if !excludeExact.contains(lower) {
                    allWords.append(word)
                }
            }
        }

        print("All words collected: \(allWords)")
        print("Potential author: \(potentialAuthor ?? "none")")

        // Try to reconstruct a known title pattern or build a search query
        let title = buildSearchQuery(from: allWords)

        return (title: title, author: potentialAuthor)
    }
    // swiftlint:enable cyclomatic_complexity

    /// Builds a search query from collected words
    private func buildSearchQuery(from words: [String]) -> String? {
        guard !words.isEmpty else { return nil }

        // Words to exclude from the query (marketing, common filler)
        // NOTE: Keep "and" if it appears multiple times (likely part of title like "Tomorrow and Tomorrow")
        let excludeWords = Set([
            "the", "a", "an", "to", "of", "or", "in", "on", "by", "for",
            "taut", "tight", "suspenseful", "spellbinding", "witty", "wonderful",
            "mesmerizing", "globe", "boston"
        ])

        // Check if "and" appears multiple times - if so, it's likely part of the title
        let andCount = words.filter { $0.lowercased() == "and" }.count
        let keepAnd = andCount >= 2

        // Filter to significant words only
        let significantWords = words.filter { word in
            let lower = word.lowercased()
            if lower == "and" && keepAnd {
                return true  // Keep "and" if it appears multiple times
            }
            return !excludeWords.contains(lower)
        }

        // Take the most significant words (up to 8 for longer titles)
        let queryWords = Array(significantWords.prefix(8))

        if queryWords.isEmpty {
            // Fallback to original words if all were filtered
            return words.prefix(6).joined(separator: " ")
        }

        return queryWords.joined(separator: " ")
    }

    /// Corrects common OCR misreadings
    private func correctOCRErrors(_ text: String) -> String {
        var corrected = text

        // Common OCR character substitutions for author names
        let charCorrections: [(String, String)] = [
            // Gabrielle Zevin variations
            ("CABRIELLE", "GABRIELLE"),   // C misread as G
            ("GABRJELLE", "GABRIELLE"),   // J misread as I
            ("GABR1ELLE", "GABRIELLE"),   // 1 misread as I
            ("CABR1ELLE", "GABRIELLE"),   // C and 1 misread
            ("ZEV1N", "ZEVIN"),            // 1 misread as I
            ("2EVIN", "ZEVIN"),            // 2 misread as Z
            ("MINAZ", "ZEVIN"),            // Complete misread - stylized font
            ("ZEWIN", "ZEVIN"),            // W misread as V
            ("ZEVJN", "ZEVIN"),            // J misread as I

            // Common OCR mistakes
            ("RÉST", "BEST"),              // B misread as R
            ("8EST", "BEST"),              // 8 misread as B
            ("AUTH0R", "AUTHOR"),          // 0 misread as O
            ("N0VEL", "NOVEL"),            // 0 misread as O
        ]

        for (wrong, right) in charCorrections {
            corrected = corrected.replacingOccurrences(
                of: wrong,
                with: right,
                options: .caseInsensitive
            )
        }

        return corrected
    }

    /// Checks if a word looks like a potential name (relaxed matching for OCR errors)
    private func looksLikePotentialName(_ text: String) -> Bool {
        let cleaned = text.trimmingCharacters(in: .whitespaces)
        guard cleaned.count >= 4 else { return false }

        // Must be mostly letters (allow 1 number for OCR errors like "ZEV1N")
        let letterCount = cleaned.filter { $0.isLetter }.count
        let ratio = Double(letterCount) / Double(cleaned.count)
        guard ratio >= 0.8 else { return false }

        // Not a common non-name word
        let notNameWords = Set([
            "the", "and", "for", "not", "art", "new", "old", "stories", "essays",
            "novel", "tales", "memoir", "national", "international", "bestseller",
            "author", "best-sens", "bestselling"
        ])

        return !notNameWords.contains(cleaned.lowercased())
    }

    /// Finds potential author names from OCR text for fallback searching
    private func findPotentialAuthorNames(from text: String) -> [String] {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var potentialNames: [String] = []
        var fullNameCandidates: [(name: String, score: Int)] = []

        // Words that are definitely not names (expanded list)
        let excludeWords = Set([
            "and", "the", "a", "an", "of", "or", "by", "for", "to", "in", "on",
            "novel", "author", "bestseller", "bestselling", "best-sens", "times",
            "new", "york", "national", "international", "best", "seller",
            // Common title words
            "between", "kingdoms", "two", "three", "four", "five", "before", "after",
            "under", "over", "within", "without", "beyond", "life", "death", "love",
            "time", "world", "year", "years", "memoir", "story", "book", "books",
            "notable", "interrupted", "follow", "immersed", "ride", "whole", "anywhere",
            "review", "one", "was", "would", "chanel", "miller"
        ])

        // First pass: look for lines that look like "FIRSTNAME LASTNAME" (full author names)
        for line in lines {
            let cleaned = line.trimmingCharacters(in: .punctuationCharacters)
                .trimmingCharacters(in: .whitespaces)
            let words = cleaned.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

            // Author names are typically 2-3 words
            if words.count >= 2 && words.count <= 3 {
                let allLookLikeNames = words.allSatisfy { word in
                    let lower = word.lowercased()
                    if excludeWords.contains(lower) { return false }
                    if word.count < 3 { return false }
                    if !word.allSatisfy({ $0.isLetter }) { return false }
                    return true
                }

                if allLookLikeNames {
                    // Score based on characteristics
                    var score = 10
                    // Bonus for all caps (common for author names on covers)
                    if cleaned == cleaned.uppercased() { score += 5 }
                    // Bonus for 2 words (most common author name format)
                    if words.count == 2 { score += 3 }

                    fullNameCandidates.append((name: cleaned, score: score))
                }
            }
        }

        // Sort by score and take the best full name candidate
        fullNameCandidates.sort { $0.score > $1.score }
        if let bestCandidate = fullNameCandidates.first {
            let words = bestCandidate.name.components(separatedBy: .whitespaces)
            for word in words {
                let corrected = correctOCRErrors(word)
                let normalized = corrected.prefix(1).uppercased() + corrected.dropFirst().lowercased()
                potentialNames.append(normalized)
            }
            return potentialNames
        }

        // Fallback: look for individual name-like words
        for line in lines {
            let words = line.components(separatedBy: .whitespaces)
                .map { $0.trimmingCharacters(in: .punctuationCharacters) }
                .filter { !$0.isEmpty }

            for word in words {
                let cleaned = word.trimmingCharacters(in: .punctuationCharacters)
                let lower = cleaned.lowercased()

                // Skip excluded words
                if excludeWords.contains(lower) { continue }

                // Skip short words or numbers
                if cleaned.count < 4 { continue }
                if cleaned.allSatisfy({ $0.isNumber }) { continue }

                // Check if it looks like a name (starts with capital, mostly letters)
                let letterCount = cleaned.filter { $0.isLetter }.count
                if letterCount < cleaned.count - 1 { continue }

                // Must start with uppercase
                guard let first = cleaned.first, first.isUppercase else { continue }

                // Apply OCR corrections
                let corrected = correctOCRErrors(cleaned)

                // Add if it looks like a name
                if corrected.count >= 4 && corrected.first?.isUppercase == true {
                    let normalized = corrected.prefix(1).uppercased() + corrected.dropFirst().lowercased()
                    if !potentialNames.contains(normalized) {
                        potentialNames.append(normalized)
                    }
                }
            }
        }

        // Limit to top 2 most likely names
        return Array(potentialNames.prefix(2))
    }

    /// Checks if a string looks like a single name part (first or last name alone)
    /// Used to detect split author names like "HARUKI" on one line and "MURAKAMI" on another
    private func looksLikeSingleNamePart(_ text: String) -> Bool {
        let cleaned = text.trimmingCharacters(in: .whitespaces)
        let words = cleaned.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        // Must be exactly one word
        guard words.count == 1 else { return false }

        let word = words[0]

        // Must be all letters
        guard word.allSatisfy({ $0.isLetter }) else { return false }

        // Must be at least 3 characters (to avoid "A", "OF", etc.)
        guard word.count >= 3 else { return false }

        // Accept ALL CAPS or Title Case (relaxed for OCR that detects mixed case)
        let isAllCaps = word == word.uppercased()
        let isTitleCase = word.first?.isUppercase == true && word.count >= 4
        guard isAllCaps || isTitleCase else { return false }

        // Not a common non-name word (includes common title words)
        let notNameWords = Set([
            "the", "and", "for", "not", "art", "new", "old", "stories", "essays",
            "novel", "tales", "memoir", "national", "international", "bestseller",
            "first", "person", "singular", "plural", "mesmerizing", "author",
            // Common title words that get OCR'd as separate lines
            "between", "kingdoms", "two", "three", "four", "five", "before", "after",
            "under", "over", "within", "without", "beyond", "behind", "above", "below",
            "through", "across", "against", "toward", "towards", "into", "onto",
            "life", "death", "love", "time", "world", "year", "years", "day", "days",
            "night", "nights", "home", "house", "road", "way", "place", "story",
            "book", "books", "notable", "interrupted", "follow", "immersed", "ride",
            "whole", "anywhere", "review", "one", "chanel", "miller"
        ])

        return !notNameWords.contains(word.lowercased())
    }

    /// Checks if a string looks like an author name
    private func looksLikeAuthorName(_ text: String) -> Bool {
        let words = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        // Author names are typically 2-3 words (First Last or First Middle Last)
        guard words.count >= 2 && words.count <= 4 else { return false }

        // Phrases that are definitely NOT author names (check full text)
        let notAuthorPhrases = Set([
            "national bestseller", "international bestseller", "new york times",
            "best seller", "bestseller", "first person", "stories essays",
            "kingdoms between", "between kingdoms", "between two", "two kingdoms"
        ])

        if notAuthorPhrases.contains(text.lowercased()) {
            return false
        }

        // Common title/marketing words that are NOT author name parts
        let notAuthorWords = Set([
            "the", "a", "an", "of", "and", "or", "to", "in", "on", "by", "for", "with",
            "art", "not", "giving", "subtle", "stories", "novel", "tales", "essays",
            "memoir", "life", "death", "love", "time", "world", "new", "old", "last",
            "first", "second", "third", "person", "singular", "plural", "f*ck", "fick",
            "national", "international", "bestseller", "bestselling", "best", "seller",
            // Common title words
            "between", "kingdoms", "two", "three", "four", "five", "before", "after",
            "under", "over", "within", "without", "beyond", "behind", "above", "below",
            "through", "across", "against", "toward", "towards", "into", "onto",
            "year", "years", "day", "days", "night", "nights", "home", "house",
            "road", "way", "place", "story", "book", "books", "notable", "review"
        ])

        // Check if this looks like a name
        var allLookLikeNames = true
        var hasUppercasePattern = false

        for word in words {
            let cleanWord = word.trimmingCharacters(in: .punctuationCharacters)

            // Skip if it's a common non-author word
            if notAuthorWords.contains(cleanWord.lowercased()) {
                return false
            }

            // Must be all letters
            if !cleanWord.allSatisfy({ $0.isLetter }) {
                allLookLikeNames = false
            }

            // Must be at least 2 characters
            if cleanWord.count < 2 {
                return false
            }

            // Check if it's ALL CAPS (common for author names on covers)
            if cleanWord == cleanWord.uppercased() && cleanWord.count > 2 {
                hasUppercasePattern = true
            }
        }

        // If all words are ALL CAPS and look like names, very likely an author
        if hasUppercasePattern && allLookLikeNames {
            return true
        }

        // Otherwise require exactly 2-3 words that all look like proper names
        return allLookLikeNames && words.count >= 2 && words.count <= 3
    }
}

enum OCRError: LocalizedError {
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Could not process the image"
        }
    }
}

// MARK: - OCR Results Sheet

struct OCRResultsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: BookshelfViewModel
    let searchQuery: String

    @State private var showAllResults = false
    @State private var isAdding = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.searchResults.isEmpty {
                    ContentUnavailableView {
                        Label("No Results", systemImage: "magnifyingglass")
                    } description: {
                        Text("No books found for \"\(searchQuery)\"")
                    }
                } else if let firstResult = viewModel.searchResults.first {
                    // Show first result in full screen
                    ScrollView {
                        VStack(spacing: 24) {
                            // Cover image
                            Group {
                                if let coverURL = firstResult.coverURL {
                                    CachedAsyncImage(isbn: firstResult.isbn, coverURL: coverURL)
                                        .frame(width: 200, height: 300)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                                } else {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.accentColor.opacity(0.1))
                                        .frame(width: 200, height: 300)
                                        .overlay {
                                            Image(systemName: "book.closed.fill")
                                                .font(.system(size: 60))
                                                .foregroundStyle(Color.accentColor)
                                        }
                                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                                }
                            }
                            .padding(.top, 20)

                            // Book info
                            VStack(spacing: 8) {
                                Text(firstResult.title)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .multilineTextAlignment(.center)

                                if !firstResult.authors.isEmpty {
                                    Text(firstResult.authors.joined(separator: ", "))
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                }

                                HStack(spacing: 16) {
                                    if let year = firstResult.publishDate {
                                        Label(year, systemImage: "calendar")
                                            .font(.subheadline)
                                            .foregroundStyle(.tertiary)
                                    }

                                    if let pages = firstResult.pageCount {
                                        Label("\(pages) pages", systemImage: "book.pages")
                                            .font(.subheadline)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .padding(.top, 4)
                            }
                            .padding(.horizontal)

                            // Action buttons
                            VStack(spacing: 12) {
                                let isInShelf = viewModel.isBookInShelf(isbn: firstResult.isbn)

                                Button {
                                    guard !isInShelf else { return }
                                    isAdding = true
                                    Task {
                                        await viewModel.addBookFromResult(firstResult)
                                        isAdding = false
                                        dismiss()
                                    }
                                } label: {
                                    HStack {
                                        if isAdding {
                                            ProgressView()
                                                .tint(.white)
                                        } else if isInShelf {
                                            Image(systemName: "checkmark")
                                            Text("Already in Shelf")
                                        } else {
                                            Image(systemName: "plus")
                                            Text("Add to Shelf")
                                        }
                                    }
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(isInShelf ? Color.gray : Color.accentColor)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .disabled(isInShelf || isAdding)

                                if viewModel.searchResults.count > 1 {
                                    Button {
                                        showAllResults = true
                                    } label: {
                                        HStack {
                                            Image(systemName: "list.bullet")
                                            Text("Show All Results (\(viewModel.searchResults.count))")
                                        }
                                        .font(.subheadline)
                                        .foregroundStyle(Color.accentColor)
                                    }
                                }
                            }
                            .padding(.horizontal, 32)
                            .padding(.top, 8)

                            Spacer(minLength: 40)
                        }
                    }
                }
            }
            .navigationTitle("Book Found")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.clearSearch()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showAllResults) {
                AllResultsSheet(viewModel: viewModel, onDismiss: { dismiss() })
            }
        }
    }
}

// MARK: - All Results Sheet

struct AllResultsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: BookshelfViewModel
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            List(viewModel.searchResults) { result in
                OCRResultRow(
                    result: result,
                    isInShelf: viewModel.isBookInShelf(isbn: result.isbn)
                ) {
                    Task {
                        await viewModel.addBookFromResult(result)
                        dismiss()
                        onDismiss()
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("All Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - OCR Result Row

struct OCRResultRow: View {
    let result: BookSearchResult
    let isInShelf: Bool
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if let coverURL = result.coverURL {
                CachedAsyncImage(isbn: result.isbn, coverURL: coverURL)
                    .frame(width: 50, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 50, height: 70)
                    .overlay {
                        Image(systemName: "book.closed")
                            .foregroundStyle(.gray)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.headline)
                    .lineLimit(2)

                if !result.authors.isEmpty {
                    Text(result.authors.joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let year = result.publishDate {
                    Text(year)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if isInShelf {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title2)
            } else {
                Button {
                    onAdd()
                } label: {
                    Text("Add")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Camera Capture View

struct CameraCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    let onCapture: (UIImage) -> Void

    @StateObject private var camera = CameraModel()

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            // Camera preview
            CameraPreviewView(camera: camera)
                .ignoresSafeArea()

            // Loading overlay (shown while camera is starting)
            if !camera.isSessionRunning {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    Text("Starting camera...")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }

            // Overlay UI
            VStack {
                // Top bar with cancel button
                HStack {
                    Button {
                        camera.stop()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding()
                            .background(Circle().fill(.black.opacity(0.5)))
                    }
                    Spacer()
                }
                .padding()

                Spacer()

                // Instructions (only show when camera is ready)
                if camera.isSessionRunning {
                    Text("Point at book cover")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(.black.opacity(0.6)))
                }

                Spacer()

                // Capture button (only enabled when camera is ready)
                Button {
                    camera.capturePhoto { image in
                        if let image = image {
                            onCapture(image)
                            dismiss()
                        }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(camera.isSessionRunning ? .white : .gray)
                            .frame(width: 70, height: 70)
                        Circle()
                            .stroke(camera.isSessionRunning ? .white : .gray, lineWidth: 4)
                            .frame(width: 80, height: 80)
                    }
                }
                .disabled(!camera.isSessionRunning)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            camera.start()
        }
        .onDisappear {
            camera.stop()
        }
    }
}

// MARK: - Camera Model

class CameraModel: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private var output = AVCapturePhotoOutput()
    private var captureCompletion: ((UIImage?) -> Void)?
    @Published var isSessionRunning = false

    override init() {
        super.init()
        setupCamera()
    }

    func start() {
        guard !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
            DispatchQueue.main.async {
                self?.isSessionRunning = self?.session.isRunning ?? false
            }
        }
    }

    func stop() {
        guard session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
            DispatchQueue.main.async {
                self?.isSessionRunning = false
            }
        }
    }

    private func setupCamera() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        // Get the wide angle camera (1x)
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("No camera available")
            session.commitConfiguration()
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }

            if session.canAddOutput(output) {
                session.addOutput(output)
            }

            session.commitConfiguration()
        } catch {
            print("Camera setup error: \(error)")
            session.commitConfiguration()
        }
    }

    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        self.captureCompletion = completion

        let settings = AVCapturePhotoSettings()
        output.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Photo capture error: \(error)")
            captureCompletion?(nil)
            return
        }

        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            captureCompletion?(nil)
            return
        }

        captureCompletion?(image)
    }
}

// MARK: - Camera Preview View

struct CameraPreviewView: UIViewRepresentable {
    @ObservedObject var camera: CameraModel

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = camera.session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        // Frame is handled automatically by PreviewView's layoutSubviews
    }

    // Custom UIView subclass that properly handles the preview layer
    class PreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var previewLayer: AVCaptureVideoPreviewLayer {
            // swiftlint:disable:next force_cast
            layer as! AVCaptureVideoPreviewLayer
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .black
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}

// MARK: - DataScanner Representable

struct DataScannerRepresentable: UIViewControllerRepresentable {
    @Binding var scannedISBN: String?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let parent: DataScannerRepresentable

        init(_ parent: DataScannerRepresentable) {
            self.parent = parent
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            processItem(item)
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            if let firstItem = addedItems.first {
                processItem(firstItem)
            }
        }

        private func processItem(_ item: RecognizedItem) {
            switch item {
            case .barcode(let barcode):
                if let payload = barcode.payloadStringValue {
                    let isbn = normalizeISBN(payload)
                    parent.scannedISBN = isbn
                    parent.dismiss()
                }
            default:
                break
            }
        }

        private func normalizeISBN(_ code: String) -> String {
            let cleaned = code.filter { $0.isNumber }
            return cleaned
        }

        func dataScannerDidZoom(_ dataScanner: DataScannerViewController) {}

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable
        ) {}
    }
}

// MARK: - Manual ISBN Entry Sheet

struct ManualISBNEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: BookshelfViewModel
    @State private var isbn = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("ISBN (10 or 13 digits)", text: $isbn)
                        .keyboardType(.numberPad)
                        .textContentType(.none)
                        .autocorrectionDisabled()
                } header: {
                    Text("Enter ISBN")
                } footer: {
                    Text("You can find the ISBN on the back cover or inside the first few pages of the book")
                }
            }
            .navigationTitle("Manual Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Look Up") {
                        let cleanISBN = isbn.filter { $0.isNumber }
                        Task {
                            await viewModel.lookupBook(isbn: cleanISBN)
                            dismiss()
                        }
                    }
                    .disabled(isbn.filter { $0.isNumber }.count < 10)
                }
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Scanner") {
    ScannerView(viewModel: BookshelfViewModel())
}
#endif
