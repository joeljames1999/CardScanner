import Foundation
import Combine

// MARK: - Scanner State

enum ScannerState: Equatable {
    case idle
    case detecting          // rectangle found, running OCR
    case found(MTGCard)
    case error(String)

    static func == (lhs: ScannerState, rhs: ScannerState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.detecting, .detecting): return true
        case (.found(let a), .found(let b)):            return a.id == b.id
        case (.error(let a), .error(let b)):            return a == b
        default:                                        return false
        }
    }
}

// MARK: - ScannerViewModel

@MainActor
final class ScannerViewModel: ObservableObject {

    @Published private(set) var state: ScannerState = .idle

    private let scryfallService = ScryfallService()
    private var lookupTask: Task<Void, Never>?
    private var lastLookedUpName: String = ""

    // MARK: Public

    /// Called by OCRService when a card name candidate is found
    func handleDetectedName(_ name: String) {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty,
              cleaned.lowercased() != lastLookedUpName.lowercased()
        else { return }

        state = .detecting
        lookupCard(named: cleaned)
    }

    func resetToIdle() {
        lookupTask?.cancel()
        lastLookedUpName = ""
        state = .idle
    }

    func resetAfterPresentation() {
        // Keep cooldown in OCRService — just reset state here
        lastLookedUpName = ""
        state = .idle
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
                if case .cardNotFound = error {
                    // Silently ignore — bad OCR frame, will retry
                    lastLookedUpName = ""
                    state = .idle
                    return
                }
                state = .error(error.localizedDescription)
            } catch {
                guard !Task.isCancelled else { return }
                lastLookedUpName = ""
                state = .idle
            }
        }
    }
}
