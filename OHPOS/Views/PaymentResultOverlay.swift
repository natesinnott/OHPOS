//
//  PaymentResultOverlay.swift
//  OHPOS
//
//  Payment Result Overlay construction
//

import SwiftUI


struct PaymentResultOverlay: View {
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
                Image(systemName: result == .approved ? "checkmark.circle" : "creditcard.trianglebadge.exclamationmark")
                    .foregroundColor(result == .approved ? .green : .red)
                    .font(.system(size: 72, weight: .bold))
                    .symbolRenderingMode(.hierarchical)
                Text(result == .approved ? "Payment Approved" : "Payment Failed")
                    .font(.title.bold())
                if result != .approved { Text(statusMessage).font(.caption) }
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
                    .stroke(Color.white.opacity(0.55), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
        }
    }
}
