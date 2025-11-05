//
//  PaymentResultOverlay.swift
//  OHPOS
//
//  Payment Result Overlay construction
//


import SwiftUI

struct StepPaymentResult: View {
    @ObservedObject var vm: POSViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(colorScheme == .light ? 0.35 : 0.45).ignoresSafeArea()

            VStack(spacing: 16) {
                VStack(spacing: 20) {
                    Image(systemName: vm.result == .approved ? "checkmark.circle" : "creditcard.trianglebadge.exclamationmark")
                        .foregroundColor(vm.result == .approved ? Color(red: 0, green: 1, blue: 0) : .red)
                        .font(.system(size: 72, weight: .bold))
                        .symbolRenderingMode(.hierarchical)

                    Text(vm.result == .approved ? "Payment Approved" : "Payment Failed")
                        .font(.title.weight(.bold))

                    if vm.result != .approved {
                        Text(truncatedError(vm.statusMessage))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .truncationMode(.tail)
                            .padding(.horizontal, 8)
                    }

                    Text("$" + displayAmount(vm.amountCents))
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)

                    Divider()
                        .padding(.vertical, 4)

                    Button {
                        vm.resetStateForNewTransaction()
                    } label: {
                        Label("New Transaction", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(GlassButtonStyle(isEnabled: true))
                    .accessibilityLabel("Return to new transaction")
                }
                .padding(24)
                .multilineTextAlignment(.center)
            }
            .frame(minWidth: 420, maxWidth: 560)
            .background(
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .fill(colorScheme == .light ? .regularMaterial : .ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 36, style: .continuous)
                            .fill(Color.black.opacity(colorScheme == .light ? 0.10 : 0.25))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .stroke(Color.white.opacity(colorScheme == .light ? 0.35 : 0.15), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
        }
    }
    private func truncatedError(_ message: String) -> String {
        // Limit to a user-friendly summary (around 120 characters)
        if message.count > 120 {
            let prefix = message.prefix(117)
            return String(prefix) + "…"
        } else {
            return message
        }
    }
}

#Preview {
    StepPaymentResult(vm: POSViewModel())
}
