//
//  GlassCard.swift
//  OHPOS
//
//  Created by Nate Sinnott on 24/10/2025.
//

import SwiftUI

struct GlassCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var hSize
    @ViewBuilder var content: Content
    var body: some View {
        // Adaptive padding for compact vs regular layouts
        let basePad: CGFloat = (hSize == .compact) ? 16 : 24
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)

        content
            .padding(basePad)
            .background(
                shape
                    .fill(colorScheme == .light ? .regularMaterial : .ultraThinMaterial)
            )
            .overlay(
                shape
                    .stroke(Color.white.opacity(colorScheme == .light ? 0.35 : 0.55), lineWidth: 0.5)
            )
            .clipShape(shape)
            .shadow(
                color: .black.opacity(colorScheme == .light ? 0.10 : 0.20),
                radius: colorScheme == .light ? 12 : 18,
                y: colorScheme == .light ? 8 : 12
            )
    }
}
