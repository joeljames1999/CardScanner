import Foundation
import Combine

// MARK: - Scanner State

enum ScannerState: Equatable {
    case idle
    case scanning
    case found(MTGCard)
    case error(String)

    static func == (lhs: ScannerState, rhs: ScannerState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.scanning, .scanning):
            return true
        case (.found(let a), .found(let b)):
            return a.id == b.id
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - ScannerViewModel

@MainActor
final class ScannerViewModel: ObservableObject {

    @Published private(set) var state: ScannerState = .idle
    @Published private(set) var lastDetectedName: String?
    @Published var isScanning: Bool = false

    private let scryfallService = ScryfallService()
    private var lookupTask: Task<Void, Never>?
    private var lastLookedUpName: String = ""

    // MARK: Public

    /// Called when OCR produces a candidate card name.
    func handleDetectedText(_ text: String) {
        guard isScanning else { return }

        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty,
              cleaned.lowercased() != lastLookedUpName.lowercased()
        else { return }

        lastDetectedName = cleaned
        lookupCard(named: cleaned)
    }

    func startScanning() {
        isScanning = true
        state = .scanning
        lastLookedUpName = ""
    }

    func stopScanning() {
        isScanning = false
        lookupTask?.cancel()
        state = .idle
    }

    func resetToScanning() {
        state = .scanning
        lastLookedUpName = ""
    }

    // MARK: Private

    private func lookupCard(named name: String) {
        lookupTask?.cancel()
        lastLookedUpName = name

        lookupTask = Task {
            do {
                let card = try await scryfallService.fetchCard(named: name)
                guard !Task.isCancelled else { return }
                state = .found(card)
            } catch let error as ScryfallService.ScryfallError {
                guard !Task.isCancelled else { return }
                // Don't show "not found" for every bad OCR frame — only surface real errors
                if case .cardNotFound = error { return }
                state = .error(error.localizedDescription ?? "Unknown error")
            } catch {
                guard !Task.isCancelled else { return }
                print("[ScannerViewModel] Lookup error: \(error)")
            }
        }
    }
}
