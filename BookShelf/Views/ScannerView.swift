import SwiftUI
import UIKit
import VisionKit
import Vision
import AVFoundation

// MARK: - OCR Status

enum OCRStatus: Equatable {
    case idle
    case processing
    case searching(String)
    case found(Int)
    case error(String)
}

// MARK: - OCR Processor

enum OCRProcessor {
    static func performOCR(on image: UIImage) async throws -> String {
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

                let sizes = observations.map { $0.boundingBox.height }
                let maxHeight = sizes.max() ?? 0
                let avgHeight = sizes.isEmpty ? 0 : sizes.reduce(0, +) / CGFloat(sizes.count)
                let sizeThreshold = max(maxHeight * 0.35, avgHeight * 0.8)

                let significantObservations = observations.filter { obs in
                    obs.boundingBox.height >= sizeThreshold
                }

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

    static func extractISBN(from text: String) -> String? {
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
    static func extractTitleAndAuthor(from text: String) -> (title: String?, author: String?) {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let excludeExact = Set([
            "new york", "times", "bestseller", "bestselling", "best seller",
            "#1", "national", "international", "a novel", "a memoir", "a thriller"
        ])

        let excludeContains = [
            "million copies", "author of", "copyright", "all rights",
            "published by", "isbn", "introduction by", "foreword by",
            "translated by", "praise for", "acclaim for", "winner of",
            "washington post", "wall street journal", "los angeles times",
            "boston globe", "new york times", "counterintuitive", "approach",
            "living a good life"
        ]

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

            if excludeExact.contains(lowercased) { continue }
            if excludeContains.contains(where: { lowercased.contains($0) }) { continue }
            if cleaned.count < 2 { continue }

            cleanedLines.append(cleaned)
        }

        var potentialAuthor: String?
        var authorLineIndices: Set<Int> = []

        var singleNameParts: [(index: Int, name: String)] = []
        for (index, line) in cleanedLines.enumerated() where looksLikeSingleNamePart(line) {
            singleNameParts.append((index: index, name: line))
        }

        if singleNameParts.count == 2 && potentialAuthor == nil {
            let combined = "\(singleNameParts[0].name) \(singleNameParts[1].name)"
            potentialAuthor = combined
            authorLineIndices.insert(singleNameParts[0].index)
            authorLineIndices.insert(singleNameParts[1].index)
        }

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
                            break
                        }
                    }
                }
            }
        }

        if potentialAuthor == nil {
            for (index, line) in cleanedLines.enumerated() where looksLikeAuthorName(line) {
                potentialAuthor = line
                authorLineIndices.insert(index)
                break
            }
        }

        var allWords: [String] = []
        for (index, line) in cleanedLines.enumerated() {
            if authorLineIndices.contains(index) { continue }

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

        let title = buildSearchQuery(from: allWords)

        return (title: title, author: potentialAuthor)
    }
    // swiftlint:enable cyclomatic_complexity

    static func correctOCRErrors(_ text: String) -> String {
        var corrected = text

        let charCorrections: [(String, String)] = [
            ("CABRIELLE", "GABRIELLE"),
            ("GABRJELLE", "GABRIELLE"),
            ("GABR1ELLE", "GABRIELLE"),
            ("CABR1ELLE", "GABRIELLE"),
            ("ZEV1N", "ZEVIN"),
            ("2EVIN", "ZEVIN"),
            ("MINAZ", "ZEVIN"),
            ("ZEWIN", "ZEVIN"),
            ("ZEVJN", "ZEVIN"),
            ("RÉST", "BEST"),
            ("8EST", "BEST"),
            ("AUTH0R", "AUTHOR"),
            ("N0VEL", "NOVEL"),
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

    static func findPotentialAuthorNames(from text: String) -> [String] {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var potentialNames: [String] = []
        var fullNameCandidates: [(name: String, score: Int)] = []

        let excludeWords = Set([
            "and", "the", "a", "an", "of", "or", "by", "for", "to", "in", "on",
            "novel", "author", "bestseller", "bestselling", "best-sens", "times",
            "new", "york", "national", "international", "best", "seller",
            "between", "kingdoms", "two", "three", "four", "five", "before", "after",
            "under", "over", "within", "without", "beyond", "life", "death", "love",
            "time", "world", "year", "years", "memoir", "story", "book", "books",
            "notable", "interrupted", "follow", "immersed", "ride", "whole", "anywhere",
            "review", "one", "was", "would", "chanel", "miller"
        ])

        for line in lines {
            let cleaned = line.trimmingCharacters(in: .punctuationCharacters)
                .trimmingCharacters(in: .whitespaces)
            let words = cleaned.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

            if words.count >= 2 && words.count <= 3 {
                let allLookLikeNames = words.allSatisfy { word in
                    let lower = word.lowercased()
                    if excludeWords.contains(lower) { return false }
                    if word.count < 3 { return false }
                    if !word.allSatisfy({ $0.isLetter }) { return false }
                    return true
                }

                if allLookLikeNames {
                    var score = 10
                    if cleaned == cleaned.uppercased() { score += 5 }
                    if words.count == 2 { score += 3 }
                    fullNameCandidates.append((name: cleaned, score: score))
                }
            }
        }

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

        for line in lines {
            let words = line.components(separatedBy: .whitespaces)
                .map { $0.trimmingCharacters(in: .punctuationCharacters) }
                .filter { !$0.isEmpty }

            for word in words {
                let cleaned = word.trimmingCharacters(in: .punctuationCharacters)
                let lower = cleaned.lowercased()

                if excludeWords.contains(lower) { continue }
                if cleaned.count < 4 { continue }
                if cleaned.allSatisfy({ $0.isNumber }) { continue }

                let letterCount = cleaned.filter { $0.isLetter }.count
                if letterCount < cleaned.count - 1 { continue }

                guard let first = cleaned.first, first.isUppercase else { continue }

                let corrected = correctOCRErrors(cleaned)

                if corrected.count >= 4 && corrected.first?.isUppercase == true {
                    let normalized = corrected.prefix(1).uppercased() + corrected.dropFirst().lowercased()
                    if !potentialNames.contains(normalized) {
                        potentialNames.append(normalized)
                    }
                }
            }
        }

        return Array(potentialNames.prefix(2))
    }

    // MARK: - Private Helpers

    private static func buildSearchQuery(from words: [String]) -> String? {
        guard !words.isEmpty else { return nil }

        let excludeWords = Set([
            "the", "a", "an", "to", "of", "or", "in", "on", "by", "for",
            "taut", "tight", "suspenseful", "spellbinding", "witty", "wonderful",
            "mesmerizing", "globe", "boston"
        ])

        let andCount = words.filter { $0.lowercased() == "and" }.count
        let keepAnd = andCount >= 2

        let significantWords = words.filter { word in
            let lower = word.lowercased()
            if lower == "and" && keepAnd {
                return true
            }
            return !excludeWords.contains(lower)
        }

        let queryWords = Array(significantWords.prefix(8))

        if queryWords.isEmpty {
            return words.prefix(6).joined(separator: " ")
        }

        return queryWords.joined(separator: " ")
    }

    private static func looksLikeSingleNamePart(_ text: String) -> Bool {
        let cleaned = text.trimmingCharacters(in: .whitespaces)
        let words = cleaned.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        guard words.count == 1 else { return false }

        let word = words[0]

        guard word.allSatisfy({ $0.isLetter }) else { return false }
        guard word.count >= 3 else { return false }

        let isAllCaps = word == word.uppercased()
        let isTitleCase = word.first?.isUppercase == true && word.count >= 4
        guard isAllCaps || isTitleCase else { return false }

        let notNameWords = Set([
            "the", "and", "for", "not", "art", "new", "old", "stories", "essays",
            "novel", "tales", "memoir", "national", "international", "bestseller",
            "first", "person", "singular", "plural", "mesmerizing", "author",
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

    private static func looksLikeAuthorName(_ text: String) -> Bool {
        let words = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        guard words.count >= 2 && words.count <= 4 else { return false }

        let notAuthorPhrases = Set([
            "national bestseller", "international bestseller", "new york times",
            "best seller", "bestseller", "first person", "stories essays",
            "kingdoms between", "between kingdoms", "between two", "two kingdoms"
        ])

        if notAuthorPhrases.contains(text.lowercased()) {
            return false
        }

        let notAuthorWords = Set([
            "the", "a", "an", "of", "and", "or", "to", "in", "on", "by", "for", "with",
            "art", "not", "giving", "subtle", "stories", "novel", "tales", "essays",
            "memoir", "life", "death", "love", "time", "world", "new", "old", "last",
            "first", "second", "third", "person", "singular", "plural", "f*ck", "fick",
            "national", "international", "bestseller", "bestselling", "best", "seller",
            "between", "kingdoms", "two", "three", "four", "five", "before", "after",
            "under", "over", "within", "without", "beyond", "behind", "above", "below",
            "through", "across", "against", "toward", "towards", "into", "onto",
            "year", "years", "day", "days", "night", "nights", "home", "house",
            "road", "way", "place", "story", "book", "books", "notable", "review"
        ])

        var allLookLikeNames = true
        var hasUppercasePattern = false

        for word in words {
            let cleanWord = word.trimmingCharacters(in: .punctuationCharacters)

            if notAuthorWords.contains(cleanWord.lowercased()) {
                return false
            }

            if !cleanWord.allSatisfy({ $0.isLetter }) {
                allLookLikeNames = false
            }

            if cleanWord.count < 2 {
                return false
            }

            if cleanWord == cleanWord.uppercased() && cleanWord.count > 2 {
                hasUppercasePattern = true
            }
        }

        if hasUppercasePattern && allLookLikeNames {
            return true
        }

        return allLookLikeNames && words.count >= 2 && words.count <= 3
    }
}

// MARK: - OCR Error

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
                    ScrollView {
                        VStack(spacing: 24) {
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
            Color.black.ignoresSafeArea()

            CameraPreviewView(camera: camera)
                .ignoresSafeArea()

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

            VStack {
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

                if camera.isSessionRunning {
                    Text("Point at book cover")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(.black.opacity(0.6)))
                }

                Spacer()

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

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
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

    func updateUIView(_ uiView: PreviewView, context: Context) {}

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
