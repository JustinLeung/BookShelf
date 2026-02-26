import SwiftUI
import UIKit
import Vision

struct QuoteScannerView: View {
    let bookISBN: String
    @Bindable var viewModel: BookshelfViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showQuoteEdit = false
    @State private var scannedText = ""
    @State private var scannedImageData: Data?

    var body: some View {
        CameraCaptureView { image in
            scannedImageData = image.jpegData(compressionQuality: 0.7)
            Task {
                do {
                    scannedText = try await performQuoteOCR(on: image)
                    showQuoteEdit = true
                } catch {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showQuoteEdit) {
            QuoteEditView(
                bookISBN: bookISBN,
                initialText: scannedText,
                sourceImageData: scannedImageData,
                viewModel: viewModel
            ) {
                dismiss()
            }
        }
    }

    /// OCR variant that captures all text (not just large title text)
    private func performQuoteOCR(on image: UIImage) async throws -> String {
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

                // Capture ALL text, sorted top-to-bottom
                let sorted = observations.sorted { obs1, obs2 in
                    (1 - obs1.boundingBox.midY) < (1 - obs2.boundingBox.midY)
                }

                let text = sorted.compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")

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
}
