//
//  OHPBackground.swift
//  OHPOS
//
//  Colors and styles for UI background
//

import SwiftUI

struct OHPBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Brand gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.02, green: 0.20, blue: 0.30), // ~#04344c (darkened)
                    Color(red: 0.01, green: 0.34, blue: 0.37)  // ~#025960 (darkened)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Vignette (stronger in light mode for readability)
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(colorScheme == .light ? 0.40 : 0.16),
                    .clear
                ]),
                center: .center,
                startRadius: 0,
                endRadius: 900
            )
        }
        .ignoresSafeArea(.all)
    }
}

#Preview { OHPBackground() }
