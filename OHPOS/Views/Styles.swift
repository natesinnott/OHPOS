//
//  Keypad.swift
//  OHPOS
//
//  Reusable styles
//

import SwiftUI


struct Keypad: View {
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
                                    .contentShape(Rectangle())
                                    .accessibilityLabel(key)
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

struct GlassPadStyle: ButtonStyle {
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

struct GlassButtonStyle: ButtonStyle {
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
