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

    private let backend: TerminalBackend

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.waitsForConnectivity = true
        cfg.allowsConstrainedNetworkAccess = true
        cfg.allowsExpensiveNetworkAccess = true
        cfg.timeoutIntervalForRequest = 12
        cfg.timeoutIntervalForResource = 30
        return URLSession(configuration: cfg)
    }()

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
        statusMessage = "Creating PaymentIntent…"

        guard let url = URL(string: "https://api.operahouseplayers.org/api/payments") else {
            statusMessage = "Error: Invalid backend URL"
            isCharging = false
            return
        }

        let payload: [String: Any] = [
            "amount": amountCents,
            "currency": "usd",
            "category": category?.rawValue ?? "unknown"
        ]

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        self.session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            Task { @MainActor in
                if let error = error {
                    self.statusMessage = "Network error: \(error.localizedDescription)"
                    self.isCharging = false
                    self.result = .failed
                    self.scheduleReset(finalWasSuccess: false)
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    self.statusMessage = "No response from backend"
                    self.isCharging = false
                    self.result = .failed
                    self.scheduleReset(finalWasSuccess: false)
                    return
                }

                guard (200..<300).contains(httpResponse.statusCode),
                      let data = data,
                      let create = try? JSONDecoder().decode(CreatePIResponse.self, from: data) else {
                    self.statusMessage = "Backend error: \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))"
                    self.isCharging = false
                    self.result = .failed
                    self.scheduleReset(finalWasSuccess: false)
                    return
                }

                let intentID = create.id
                self.statusMessage = "Sending to reader…"

                Task { @MainActor in
                    do {
                        let success = try await self.backend.processOnReader(paymentIntentId: intentID)
                        if success {
                            self.statusMessage = "Processing on reader…"
                        } else {
                            // Treat a failed start as indeterminate; verify with backend before declaring failure
                            self.awaitingNetworkRecovery = true
                            self.pendingIntentId = intentID
                            self.statusMessage = "Reader error — verifying payment…"
                            await self.pollUntilTerminal(intentID: intentID)
                            return
                        }

                        // --- Polling ---
                        if success {
                            self.statusMessage = "Processing on reader…"
                            await self.pollUntilTerminal(intentID: intentID)
                        }
                    } catch {
                        // Treat network errors/timeouts as INDETERMINATE: verify with backend instead of failing immediately
                        self.awaitingNetworkRecovery = true
                        self.pendingIntentId = intentID
                        self.statusMessage = "Network issue — verifying payment…"
                        await self.pollUntilTerminal(intentID: intentID)
                        return
                    }
                }
            }
        }.resume()
    }

    private func fail(_ message: String) {
        statusMessage = "Payment failed (\(message))"
        result = .failed
    }

    // MARK: - Sounds
    // Common system sound IDs worth trying for decline:
    // 1022: Classic short failure beep
    // 1053: Critical error buzz (longer)
    // 1073: Subtle chirp ("number not in service" vibe)
    // 1006: Default alert chime
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
                    } else if let outcome = piStatus.latest_charge_outcome_type,
                              ["issuer_declined", "blocked", "reversed"].contains(outcome) {
                        finished = true
                        ticker?.cancel(); ticker = nil
                        let msg = piStatus.latest_charge_outcome_seller_message ?? "Card declined"
                        playDeclineSound()
                        fail(msg)
                    } else if let failMsg = piStatus.latest_charge_failure_message, !failMsg.isEmpty {
                        finished = true
                        self.awaitingNetworkRecovery = false
                        self.pendingIntentId = nil
                        ticker?.cancel(); ticker = nil
                        playDeclineSound()
                        fail(failMsg)
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
                    playDeclineSound()
                    fail(piStatus.status)

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
                    case "requires_payment_method":
                        finished = true
                        self.awaitingNetworkRecovery = false
                        self.pendingIntentId = nil
                        playDeclineSound()
                        fail(piStatus.latest_charge_failure_message ?? "Card declined")
                    case "canceled":
                        finished = true
                        self.awaitingNetworkRecovery = false
                        self.pendingIntentId = nil
                        playDeclineSound()
                        fail("canceled")
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
        }

        // If the app never reconnected to verify the payment and polling never succeeded or failed,
        // show a clear message to check the Stripe dashboard before retrying.
        if !finalWasSuccess && finished == false {
            await MainActor.run {
                playDeclineSound()
                self.statusMessage = "Status unknown — please check Stripe dashboard before retrying."
            }
        }

        scheduleReset(finalWasSuccess: finalWasSuccess)
    }

    private func scheduleReset(finalWasSuccess: Bool) {
        let delay: Double = finalWasSuccess ? Timing.successResetDelay : Timing.failResetDelay
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                self.amountCents = 0
                self.category = nil
                self.result = nil
                self.statusMessage = "Ready for next transaction."
                self.isCharging = false
            }
        }
    }
}
