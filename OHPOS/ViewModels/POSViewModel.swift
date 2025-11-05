//
//  POSViewModel.swift
//  OHPOS
//
//  Created by Nate Sinnott on 14/10/2025.
//

import SwiftUI
import Foundation
import Combine
import Network
import AVFoundation

enum POSStep {
    case category
    case artNumber
    case amount
    case summary
    case processing
    case result
}

fileprivate struct CreatePIResponse: Decodable { let id: String }

// MARK: - Backend Abstraction for Testability
protocol TerminalBackend {
    func processOnReader(paymentIntentId: String) async throws -> Bool
    func pollPIStatus(_ intentID: String) async throws -> PIStatus
}

struct LiveBackend: TerminalBackend {
    func processOnReader(paymentIntentId: String) async throws -> Bool {
        try await Backend.shared.processOnReader(paymentIntentId: paymentIntentId)
    }
    func pollPIStatus(_ intentID: String) async throws -> PIStatus {
        try await Backend.shared.pollPIStatus(intentID)
    }
}

@MainActor
final class POSViewModel: ObservableObject {
    // Publicly observed state
    @Published var amountCents: Int = 0
    @Published var category: Category? = nil
    @Published var isCharging: Bool = false
    @Published var result: PaymentResult? = nil
    @Published var statusMessage: String = "Idle"
    @Published var artNumber: Int? = nil

    @Published var step: POSStep = .category
    
    @Published var autoResetEnabled: Bool = false

    var canContinueFromCategory: Bool { category != nil }
    var canContinueFromArtNumber: Bool { artNumber != nil }
    var canContinueFromAmount: Bool { amountCents > 0 }

    private let backend: TerminalBackend


    private let pathMonitor = NWPathMonitor()
    private let pathQueue = DispatchQueue(label: "ohpos.netpath")
    private var awaitingNetworkRecovery = false
    private var pendingIntentId: String? = nil

    init(backend: TerminalBackend = LiveBackend()) {
        self.backend = backend

        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            Task { @MainActor in
                guard let self = self else { return }
                if self.awaitingNetworkRecovery, let pi = self.pendingIntentId {
                    self.statusMessage = "Rechecking payment status…"
                    await self.pollUntilTerminal(intentID: pi)
                }
            }
        }
        pathMonitor.start(queue: pathQueue)
    }

    func goNext() {
        switch step {
        case .category:
            if category == .art { step = .artNumber } else { step = .amount }
        case .artNumber:
            if canContinueFromArtNumber { step = .amount }
        case .amount:
            if canContinueFromAmount { step = .summary }
        case .summary:
            charge() // will advance internally
        case .processing, .result:
            break
        }
    }

    func goBack() {
        switch step {
        case .category:
            break
        case .artNumber:
            step = .category
        case .amount:
            step = (category == .art) ? .artNumber : .category
        case .summary:
            step = .amount
        case .processing, .result:
            break
        }
    }

    // Timing constants (logic-only; UI-specific constants remain in the View)
    private enum Timing {
        static let pollTotalSeconds: Int = 90
        static let pollIntervalSeconds: Int = 3
        static let waitTickMilliseconds: Int = 200
        static let successResetDelay: Double = 1.6
        static let failResetDelay: Double = 3.2
    }

    // Entry point from the UI
    func charge() {
        guard amountCents > 0 else { return }
        guard !isCharging else { return }
        isCharging = true
        step = .processing
        statusMessage = "Creating PaymentIntent…"

        if category == .art && artNumber == nil {
            // UI should prevent this, but guard anyway to avoid bad PIs
            isCharging = false
            step = .artNumber
            statusMessage = "Enter Art # (1–20)"
            return
        }

        let desc: String = {
            if category == .art, let n = artNumber { return "Art #\(n) Sale" }
            return ((category?.rawValue ?? "Payment").capitalized) + " Sale"
        }()

        Task { @MainActor in
            do {
                let create = try await Backend.shared.createPaymentIntent(
                    amount: amountCents,
                    currency: "usd",
                    category: category?.rawValue ?? "unknown",
                    artNumber: artNumber
                )

                let intentID = create.id
                self.statusMessage = "Sending to reader…"

                let success = try await self.backend.processOnReader(paymentIntentId: intentID)
                if success {
                    self.statusMessage = "Processing on reader…"
                    await self.pollUntilTerminal(intentID: intentID)
                } else {
                    self.awaitingNetworkRecovery = true
                    self.pendingIntentId = intentID
                    self.statusMessage = "Reader error — verifying payment…"
                    await self.pollUntilTerminal(intentID: intentID)
                }
            } catch {
                self.statusMessage = "Backend error: \(error.localizedDescription)"
                self.isCharging = false
                self.result = .failed
                self.step = .result
                self.scheduleReset(finalWasSuccess: false)
            }
        }
    }

    private func fail(_ message: String) {
        statusMessage = "Payment failed (\(message))"
        result = .failed
    }

    // MARK: - Sounds
    private let declineSoundID: SystemSoundID = 1053
    private func playDeclineSound() {
        AudioServicesPlaySystemSound(declineSoundID)
    }

    private func pollUntilTerminal(intentID: String) async {
        var finalWasSuccess = false
        let totalSeconds = Timing.pollTotalSeconds
        let pollIntervalNs: UInt64 = UInt64(Timing.pollIntervalSeconds) * 1_000_000_000
        let tickIntervalNs: UInt64 = UInt64(Timing.waitTickMilliseconds) * 1_000_000
        let deadline = Date().addingTimeInterval(TimeInterval(totalSeconds))

        var ticker: Task<Void, Never>? = nil
        var showingWait = false
        var finished = false
        let maxPolls = totalSeconds / 3

        var hadNetworkErrors = false

        for _ in 0..<maxPolls {
            do {
                let piStatus = try await backend.pollPIStatus(intentID)
                let statusToUse = piStatus.effectiveStatus ?? piStatus.status
                switch statusToUse {
                case "succeeded":
                    finalWasSuccess = true
                    finished = true
                    AudioServicesPlaySystemSound(1407)
                    self.awaitingNetworkRecovery = false
                    self.pendingIntentId = nil
                    ticker?.cancel(); ticker = nil
                    statusMessage = "Payment completed!"
                    result = .approved
                    self.isCharging = false
                    step = .result

                case "processing":
                    if showingWait { ticker?.cancel(); ticker = nil; showingWait = false }
                    statusMessage = "Processing on reader…"

                case "requires_payment_method":
                    if let errMsg = piStatus.errorMessage, !errMsg.isEmpty {
                        finished = true
                        self.awaitingNetworkRecovery = false
                        self.pendingIntentId = nil
                        ticker?.cancel(); ticker = nil
                        playDeclineSound()
                        fail(errMsg)
                        self.isCharging = false
                        self.step = .result
                    } else if let outcome = piStatus.latest_charge_outcome_type,
                              ["issuer_declined", "blocked", "reversed"].contains(outcome) {
                        finished = true
                        ticker?.cancel(); ticker = nil
                        let msg = piStatus.latest_charge_outcome_seller_message ?? "Card declined"
                        playDeclineSound()
                        fail(msg)
                        self.isCharging = false
                        self.step = .result
                    } else if let failMsg = piStatus.latest_charge_failure_message, !failMsg.isEmpty {
                        finished = true
                        self.awaitingNetworkRecovery = false
                        self.pendingIntentId = nil
                        ticker?.cancel(); ticker = nil
                        playDeclineSound()
                        fail(failMsg)
                        self.isCharging = false
                        self.step = .result
                    } else {
                        if !showingWait {
                            showingWait = true
                            ticker = Task {
                                while !Task.isCancelled {
                                    let remaining = max(0, Int(ceil(deadline.timeIntervalSinceNow)))
                                    await MainActor.run { self.statusMessage = "Waiting for card… (\(remaining)s)" }
                                    if remaining <= 0 { break }
                                    try? await Task.sleep(nanoseconds: tickIntervalNs)
                                }
                            }
                        }
                    }

                case "canceled", "requires_capture", "requires_confirmation", "requires_action":
                    finished = true
                    self.awaitingNetworkRecovery = false
                    self.pendingIntentId = nil
                    ticker?.cancel(); ticker = nil
                    self.statusMessage = "Card declined"
                    playDeclineSound()
                    fail(piStatus.status)
                    self.isCharging = false
                    self.step = .result

                default:
                    break
                }
            } catch {
                print("Polling error: \(error.localizedDescription)")
                hadNetworkErrors = true
            }

            if finished { break }
            try? await Task.sleep(nanoseconds: pollIntervalNs)
        }

        ticker?.cancel(); ticker = nil

        if !finished && hadNetworkErrors {
            // Give the app a short grace period to recover after network returns
            statusMessage = "Rechecking payment status…"
            let extraAttempts = 10 // ~30 seconds with 3s interval
            for _ in 0..<extraAttempts {
                do {
                    let piStatus = try await backend.pollPIStatus(intentID)
                    let statusToUse = piStatus.effectiveStatus ?? piStatus.status
                    switch statusToUse {
                    case "succeeded":
                        finalWasSuccess = true
                        finished = true
                        self.awaitingNetworkRecovery = false
                        self.pendingIntentId = nil
                        statusMessage = "Payment completed!"
                        result = .approved
                        self.isCharging = false
                        step = .result
                    case "requires_payment_method":
                        finished = true
                        self.awaitingNetworkRecovery = false
                        self.pendingIntentId = nil
                        playDeclineSound()
                        fail(piStatus.latest_charge_failure_message ?? "Card declined")
                        self.isCharging = false
                        self.step = .result
                    case "canceled":
                        finished = true
                        self.awaitingNetworkRecovery = false
                        self.pendingIntentId = nil
                        playDeclineSound()
                        fail("canceled")
                        self.isCharging = false
                        self.step = .result
                    default:
                        break
                    }
                } catch {
                    // still offline? keep looping this short grace window
                }
                if finished { break }
                try? await Task.sleep(nanoseconds: pollIntervalNs)
            }
        }

        if !finished {
            self.awaitingNetworkRecovery = false
            self.pendingIntentId = nil
            playDeclineSound()
            fail("No card presented (timeout)")
            self.isCharging = false
            self.step = .result
        }

        // If the app never reconnected to verify the payment and polling never succeeded or failed,
        // show a clear message to check the Stripe dashboard before retrying.
        if !finalWasSuccess && finished == false {
            await MainActor.run {
                playDeclineSound()
                self.statusMessage = "Status unknown — please check Stripe dashboard before retrying."
                self.isCharging = false
                self.step = .result
            }
        }

        self.isCharging = false
        scheduleReset(finalWasSuccess: finalWasSuccess)
    }

    func resetStateForNewTransaction() {
        amountCents = 0
        category = nil
        result = nil
        statusMessage = "Ready for next transaction."
        isCharging = false
        artNumber = nil
        step = .category
        // Clean up any in-flight polling context
        awaitingNetworkRecovery = false
        pendingIntentId = nil
    }

    private func scheduleReset(finalWasSuccess: Bool) {
        guard autoResetEnabled else { return }
        let delay: Double = finalWasSuccess ? Timing.successResetDelay : Timing.failResetDelay
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                self.resetStateForNewTransaction()
            }
        }
    }
}
