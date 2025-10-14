//
//  ContentView.swift
//  OHPOS
//
//  Revamped UI for iPad kiosk layout with glassmorphism and result overlay.
//

import SwiftUI

struct ContentView: View {
    // MARK: - State
    @State private var amountCents: Int = 0
    @State private var category: Category? = nil
    @State private var currencySymbol: String = "$"
    @State private var isCharging: Bool = false
    @State private var result: PaymentResult? = nil
    @State private var statusMessage: String = "Idle"
    

    var body: some View {

        GeometryReader { geo in
            let isPortrait = geo.size.height > geo.size.width
            let sidebarWidth = isPortrait
                ? min(560, max(360, geo.size.width * 0.86))
                : min(760, max(520, geo.size.width * 0.56))
            let containerHeight = isPortrait
                ? min(geo.size.height * 0.92, 860)
                : min(geo.size.height * 0.94, 920)
            ZStack {
                OHPBackground()
                    .ignoresSafeArea()

                HStack {
                    Spacer(minLength: 0)
                    VStack {
                        Spacer(minLength: 0)
                        Sidebar(
                            amountCents: $amountCents,
                            category: $category,
                            currencySymbol: currencySymbol,
                            isCharging: $isCharging,
                            statusMessage: $statusMessage,
                            isPortrait: isPortrait,
                            containerHeight: containerHeight,
                            onCharge: charge
                        )
                        .frame(maxWidth: sidebarWidth)
                        .frame(maxHeight: containerHeight)
                        .padding(.horizontal, isPortrait ? 18 : 24)
                        Spacer(minLength: 0)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 24)

                if let result {
                    PaymentResultOverlay(result: result, amountCents: amountCents, currencySymbol: currencySymbol, statusMessage: statusMessage)
                        .transition(.scale.combined(with: .opacity))
                        .zIndex(10)
                }
            }
            .preferredColorScheme(.light)
        }
    }

    // MARK: - Actions
    private func charge() {
        guard amountCents > 0 else { return }
        isCharging = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    statusMessage = "Network error: \(error.localizedDescription)"
                    isCharging = false
                    result = .failed
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    statusMessage = "No response from backend"
                    isCharging = false
                    result = .failed
                    return
                }

                guard (200..<300).contains(httpResponse.statusCode),
                      let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let intentID = json["id"] as? String else {
                    statusMessage = "Backend error: \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))"
                    isCharging = false
                    result = .failed
                    return
                }

                statusMessage = "Sending to reader…"

                Task {
                    do {
                        let success = try await Backend.shared.processOnReader(readerId: "simulated-wpe", paymentIntentId: intentID)
                        DispatchQueue.main.async {
                            if success {
                                statusMessage = "Processing on reader…"
                            } else {
                                statusMessage = "Reader error: could not start transaction"
                                result = .failed
                                isCharging = false
                                return
                            }
                        }

                        if !success {
                            // Ensure the failure overlay dismisses even if processing never started
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                    amountCents = 0
                                    category = nil
                                    result = nil
                                    statusMessage = "Ready for next transaction."
                                    isCharging = false
                                }
                            }
                        }

                        // --- Begin new polling block ---
                        if success {
                            // Smooth countdown + polling
                            statusMessage = "Processing on reader…"

                            Task {
                                var finalWasSuccess = false
                                let totalSeconds = 90
                                let pollIntervalNs: UInt64 = 3 * 1_000_000_000 // 3s
                                let tickIntervalNs: UInt64 = 200 * 1_000_000   // 0.2s
                                let deadline = Date().addingTimeInterval(TimeInterval(totalSeconds))

                                var ticker: Task<Void, Never>? = nil
                                var showingWait = false
                                var finished = false
                                let maxPolls = totalSeconds / 3

                                for _ in 0..<maxPolls {
                                    do {
                                        let piStatus = try await Backend.shared.pollPIStatus(intentID)
                                        switch piStatus.status {
                                        case "succeeded":
                                            finalWasSuccess = true
                                            finished = true
                                            ticker?.cancel(); ticker = nil
                                            DispatchQueue.main.async {
                                                statusMessage = "Payment completed!"
                                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                                result = .approved
                                            }

                                        case "processing":
                                            // Stop the waiting ticker if it was running
                                            if showingWait { ticker?.cancel(); ticker = nil; showingWait = false }
                                            DispatchQueue.main.async {
                                                statusMessage = "Processing on reader…"
                                            }

                                        case "requires_payment_method":
                                            // Treat explicit PI error or latest charge failure/outcome seller message as a decline
                                            if let errMsg = piStatus.errorMessage, !errMsg.isEmpty {
                                                finished = true
                                                ticker?.cancel(); ticker = nil
                                                DispatchQueue.main.async {
                                                    statusMessage = "Payment failed (\(errMsg))"
                                                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                                                    result = .failed
                                                }
                                            } else if let outcome = piStatus.latest_charge_outcome_type,
                                                      ["issuer_declined", "blocked", "reversed"].contains(outcome) {
                                                finished = true
                                                ticker?.cancel(); ticker = nil
                                                let msg = piStatus.latest_charge_outcome_seller_message ?? "Card declined"
                                                DispatchQueue.main.async {
                                                    statusMessage = "Payment failed (\(msg))"
                                                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                                                    result = .failed
                                                }
                                            } else if let failMsg = piStatus.latest_charge_failure_message, !failMsg.isEmpty {
                                                finished = true
                                                ticker?.cancel(); ticker = nil
                                                DispatchQueue.main.async {
                                                    statusMessage = "Payment failed (\(failMsg))"
                                                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                                                    result = .failed
                                                }
                                            } else {
                                                // Otherwise we're still waiting for a card — run smooth countdown
                                                if !showingWait {
                                                    showingWait = true
                                                    ticker = Task {
                                                        while !Task.isCancelled {
                                                            let remaining = max(0, Int(ceil(deadline.timeIntervalSinceNow)))
                                                            DispatchQueue.main.async {
                                                                statusMessage = "Waiting for card… (\(remaining)s)"
                                                            }
                                                            if remaining <= 0 { break }
                                                            try? await Task.sleep(nanoseconds: tickIntervalNs)
                                                        }
                                                    }
                                                }
                                            }

                                        case "canceled", "requires_capture", "requires_confirmation", "requires_action":
                                            finished = true
                                            ticker?.cancel(); ticker = nil
                                            DispatchQueue.main.async {
                                                statusMessage = "Payment failed (\(piStatus.status))"
                                                UINotificationFeedbackGenerator().notificationOccurred(.error)
                                                result = .failed
                                            }

                                        default:
                                            // Unknown/intermediate — keep polling
                                            break
                                        }
                                    } catch {
                                        print("Polling error: \(error.localizedDescription)")
                                    }

                                    if finished { break }
                                    try? await Task.sleep(nanoseconds: pollIntervalNs)
                                }

                                // Stop countdown if still running
                                ticker?.cancel(); ticker = nil

                                // If we exit the loop without marking a terminal state, treat as timeout
                                if !finished {
                                    DispatchQueue.main.async {
                                        statusMessage = "No card presented (timeout)"
                                        UINotificationFeedbackGenerator().notificationOccurred(.error)
                                        result = .failed
                                    }
                                }

                                // Unified reset after success/failure/timeout
                                let delay: Double = finalWasSuccess ? 1.6 : 3.2
                                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                        amountCents = 0
                                        category = nil
                                        result = nil
                                        statusMessage = "Ready for next transaction."
                                        isCharging = false
                                    }
                                }
                            }
                        }
                        // --- End new polling block ---
                    } catch {
                        DispatchQueue.main.async {
                            statusMessage = "Error processing payment: \(error.localizedDescription)"
                            result = .failed
                            isCharging = false
                        }
                    }
                }
            }
        }.resume()
    }
}

// MARK: - Sidebar
fileprivate struct Sidebar: View {
    @Binding var amountCents: Int
    @Binding var category: Category?
    let currencySymbol: String
    @Binding var isCharging: Bool
    @Binding var statusMessage: String
    let isPortrait: Bool
    let containerHeight: CGFloat
    var onCharge: () -> Void

    private var keypadHeight: CGFloat {
        // Reserve space for header and footer explicitly.
        // Portrait was previously good — keep it generous but bounded.
        let reservedTop: CGFloat = isPortrait ? 330 : 210
        let reservedBottom: CGFloat = isPortrait ? 200 : 190
        let available = max(240, containerHeight - reservedTop - reservedBottom)

        if isPortrait {
            // Portrait: allow a larger keypad and push the charge/status card down
            return max(460, min(available, 640))
        } else {
            // Landscape: shorter keys so the footer always fits
            return max(340, min(available, 460))
        }
    }

    private var chargeButtonText: String {
        if amountCents == 0 { return "Enter Amount" }
        if category == nil { return "Select Concessions or Merch" }
        return "Charge \(currencySymbol)\(displayAmount(amountCents))"
    }

    private var chargeButtonIconName: String {
        if isCharging { return "hourglass" }                 // shows during processing
        if category == nil { return "square.grid.2x2" }      // prompt to pick a type
        if amountCents == 0 { return "123.rectangle" }       // prompt to enter amount
        return "creditcard.and.123"                           // ready to charge
    }

    var body: some View {
        VStack(alignment: .center, spacing: isPortrait ? 20 : 16) {
            HStack {
                Spacer(minLength: 0)
                HeaderLogo()
                    .frame(height: 64)
                Spacer(minLength: 0)
            }

            

            Text("\(currencySymbol)\(displayAmount(amountCents))")
                .font(.system(size: 54, weight: .heavy, design: .rounded))
                .padding(.top, 4)

            GlassCard {
                Keypad(amountCents: $amountCents, currencySymbol: currencySymbol, isPortrait: isPortrait)
            }
            .frame(height: keypadHeight)
            .animation(.easeInOut(duration: 0.2), value: keypadHeight)
            
            SegmentedPill(selection: $category)

            GlassCard {
                VStack(spacing: 10) {
                    Button(action: onCharge) {
                        HStack {
                            Image(systemName: chargeButtonIconName)
                            Text(chargeButtonText)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(GlassButtonStyle(isEnabled: amountCents > 0 && (category != nil) && !isCharging))
                    .disabled((amountCents == 0) || (category == nil) || isCharging)


                    Text("Status: \(statusMessage)")
                        .font(.footnote.weight(.medium))
                        .foregroundColor(.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
}

// MARK: - Components & Styles
fileprivate struct HeaderLogo: View {
    var body: some View {
        if let _ = UIImage(named: "OHPLogo") {
            Image("OHPLogo")
                .resizable()
                .scaledToFit()
                .frame(height: 60)
        } else {
            Image(systemName: "theatermasks.fill")
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
        }
    }
}

fileprivate struct SegmentedPill: View {
    @Binding var selection: Category?
    var body: some View {
        HStack(spacing: 8) {
            ForEach(Category.allCases) { item in
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { selection = item }
                } label: {
                    Text(item.label)
                        .font(.subheadline.weight(.semibold))
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(.thinMaterial)
                                .opacity(selection == item ? 1 : 0)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
}

fileprivate struct GlassCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        content
            .padding(16)                                 // internal padding
            .background(shape.fill(.ultraThinMaterial))  // glass behind content
            .overlay(shape.stroke(Color.white.opacity(0.35), lineWidth: 0.5))
            .clipShape(shape)                            // keep content inside rounded rect
    }
}

fileprivate struct Keypad: View {
    @Binding var amountCents: Int
    let currencySymbol: String
    let isPortrait: Bool

    private let rows = [["1","2","3"],["4","5","6"],["7","8","9"],["C","0","⌫"]]

    var body: some View {
        GeometryReader { g in
            let rowsCount: CGFloat = 4
            let spacing: CGFloat = isPortrait ? 12 : 10
            let totalSpacing = spacing * (rowsCount - 1)
            // Shrink buttons a bit more in landscape; keep portrait roomy
            let buttonH = floor((g.size.height - totalSpacing) / rowsCount)
            let fontSize = min(28, buttonH * 0.42)

            VStack(spacing: spacing) {
                ForEach(rows, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(row, id: \.self) { key in
                            Button { tap(key) } label: {
                                Text(key)
                                    .font(.system(size: fontSize, weight: .semibold, design: .default))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: buttonH)
                            }
                            .buttonStyle(GlassPadStyle())
                        }
                    }
                }
            }
        }
    }

    private func tap(_ key: String) {
        switch key {
        case "C": amountCents = 0
        case "⌫": amountCents /= 10
        default:
            if let d = Int(key) {
                let next = amountCents * 10 + d
                if next <= 9_999_999 { amountCents = next }
            }
        }
    }
}

fileprivate struct PaymentResultOverlay: View {
    let result: PaymentResult
    let amountCents: Int
    let currencySymbol: String
    let statusMessage: String

    var body: some View {
        ZStack {
            // dim background
            Color.black.opacity(0.45).ignoresSafeArea()

            // Centered squircle card
            VStack(spacing: 16) {
                Image(systemName: result == .approved ? "checkmark.seal.fill" : "xmark.seal.fill")
                    .font(.system(size: 56, weight: .bold))
                    .symbolRenderingMode(.hierarchical)
                Text(result == .approved ? "Payment Approved" : "Payment Failed")
                    .font(.title2.bold())
                Text(statusMessage).font(.title3.italic())
                Text("\(currencySymbol)\(displayAmount(amountCents))")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 460, height: 300)
            .background(
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .stroke(Color.white.opacity(0.35), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
        }
    }
}

// MARK: - OHP Branding Colors and Background
extension Color {
    static var ohpPrimary: Color {
        Color(red: 0.0157, green: 0.2039, blue: 0.2980)
    }
    static var ohpPrimaryLight: Color {
        Color(red: 0.0078, green: 0.3490, blue: 0.3765)
    }
}

fileprivate struct OHPBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.ohpPrimary, Color.ohpPrimaryLight],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Color.white.opacity(0.06)
        }
    }
}

// MARK: - Styles & helpers
fileprivate struct GlassButtonStyle: ButtonStyle {
    let isEnabled: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isEnabled ? Color.accentColor : Color.gray.opacity(0.45))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.9), value: configuration.isPressed)
    }
}

fileprivate struct GlassPadStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(minWidth: 72)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.thinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.6), lineWidth: 0.5)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.85), value: configuration.isPressed)
    }
}

// MARK: - Models & Utils
enum Category: String, CaseIterable, Identifiable { case concessions, merch; var id: String { rawValue }; var label: String { rawValue.capitalized } }

enum PaymentResult { case approved, failed }

fileprivate func displayAmount(_ cents: Int) -> String {
    let v = Double(cents) / 100.0
    return String(format: "%.2f", v)
}

#Preview { ContentView() }
