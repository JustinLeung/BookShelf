import Foundation
import SwiftUI
import SwiftData

enum TimerState {
    case idle
    case running
    case paused
    case ended
}

@MainActor
@Observable
class ReadingTimerViewModel {
    var state: TimerState = .idle
    var displayTime: TimeInterval = 0
    var currentBook: Book?

    private var lastResumeWallTime: Date?
    private var accumulatedBeforePause: TimeInterval = 0
    private var displayTimer: Timer?
    private var sessionStartTime: Date?

    var formattedTime: String {
        let total = Int(displayTime)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    func startSession(for book: Book) {
        guard state == .idle else { return }
        currentBook = book
        sessionStartTime = Date()
        accumulatedBeforePause = 0
        displayTime = 0
        resume()
    }

    func resume() {
        guard state == .idle || state == .paused else { return }
        state = .running
        lastResumeWallTime = Date()
        startDisplayTimer()
    }

    func pause() {
        guard state == .running else { return }
        state = .paused
        if let lastResume = lastResumeWallTime {
            accumulatedBeforePause += Date().timeIntervalSince(lastResume)
        }
        lastResumeWallTime = nil
        stopDisplayTimer()
        recalculateDisplayTime()
    }

    func endSession(endPage: Int?, modelContext: ModelContext) {
        guard let book = currentBook, let startTime = sessionStartTime else {
            cancelSession()
            return
        }

        let finalDuration = totalElapsed()
        let endTime = Date()

        let startPage = book.currentPage
        var pagesRead: Int?
        if let endPage, let start = startPage {
            let diff = endPage - start
            if diff > 0 { pagesRead = diff }
        } else if let endPage, endPage > 0 {
            pagesRead = endPage
        }

        let session = ReadingSession(
            bookISBN: book.isbn,
            startTime: startTime,
            endTime: endTime,
            duration: finalDuration,
            pagesRead: pagesRead,
            startPage: startPage,
            endPage: endPage
        )
        modelContext.insert(session)

        // Update book progress if endPage provided
        if let endPage {
            book.currentPage = endPage
            if let pageCount = book.pageCount, pageCount > 0 {
                book.progressPercentage = min(1.0, Double(endPage) / Double(pageCount))
            }

            // Also create a ReadingProgressEntry for streak tracking
            let entry = ReadingProgressEntry(bookISBN: book.isbn, page: endPage)
            modelContext.insert(entry)
        }

        try? modelContext.save()

        state = .ended
        cleanup()
    }

    func cancelSession() {
        state = .idle
        cleanup()
    }

    func handleForeground() {
        if state == .running {
            recalculateDisplayTime()
            startDisplayTimer()
        }
    }

    func handleBackground() {
        stopDisplayTimer()
    }

    // MARK: - Private

    private func totalElapsed() -> TimeInterval {
        var total = accumulatedBeforePause
        if state == .running, let lastResume = lastResumeWallTime {
            total += Date().timeIntervalSince(lastResume)
        }
        return total
    }

    private func recalculateDisplayTime() {
        displayTime = totalElapsed()
    }

    private func startDisplayTimer() {
        stopDisplayTimer()
        displayTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recalculateDisplayTime()
            }
        }
    }

    private func stopDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = nil
    }

    private func cleanup() {
        stopDisplayTimer()
        currentBook = nil
        sessionStartTime = nil
        lastResumeWallTime = nil
        accumulatedBeforePause = 0
        displayTime = 0
        state = .idle
    }
}
