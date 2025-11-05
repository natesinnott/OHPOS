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
                                    .foregroundStyle(.primary)
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
            .frame(minWidth: 72, minHeight: 64)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(configuration.isPressed ? 0.8 : 0.5), lineWidth: 0.8)
                    )
            )
            .shadow(color: .black.opacity(configuration.isPressed ? 0.05 : 0.12), radius: configuration.isPressed ? 4 : 10, y: 4)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.85), value: configuration.isPressed)
    }
}

enum GlassButtonSize {
    case compact, standard, large

    var minHeight: CGFloat {
        switch self {
        case .compact: return 44
        case .standard: return 52
        case .large: return 64
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .compact: return 14
        case .standard: return 18
        case .large: return 22
        }
    }
}

struct GlassButtonStyle: ButtonStyle {
    let isEnabled: Bool
    var size: GlassButtonSize = .standard
    /// If true, the style will NOT set a font, allowing the label's own `.font` to drive size/scaling.
    /// Default is false to preserve legacy behavior.
    var respectsLabelFont: Bool = false
    /// If set, forces a specific Dynamic Type size. If nil, follows the environment.
    var dynamicTypeOverride: DynamicTypeSize? = nil

    @Environment(\.dynamicTypeSize) private var envDynamicTypeSize

    func makeBody(configuration: Configuration) -> some View {
        let effectiveDT = dynamicTypeOverride ?? envDynamicTypeSize
        let base = respectsLabelFont
            ? AnyView(configuration.label)
            : AnyView(configuration.label.font(.headline.weight(.semibold)))

        return base
            .foregroundStyle(isEnabled ? .white : .white.opacity(0.85))
            .frame(maxWidth: .infinity)
            .frame(minHeight: size.minHeight)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                    .fill(isEnabled ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.gray.opacity(0.32)))
            )
            // top sheen to increase brightness/legibility of enabled state
            .overlay(
                Group {
                    if isEnabled {
                        RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.14), .clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                    }
                }
            )
            // crisp rim
            .overlay(
                RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(isEnabled ? 0.55 : 0.28), lineWidth: 0.6)
            )
            .shadow(color: .black.opacity(isEnabled ? 0.35 : 0.16), radius: isEnabled ? 12 : 6, y: isEnabled ? 6 : 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.9), value: configuration.isPressed)
            .dynamicTypeSize(effectiveDT)
    }
}

struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.title
            configuration.icon
        }
    }
}
