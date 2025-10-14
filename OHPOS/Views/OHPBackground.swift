//
//  OHPBackground.swift
//  OHPOS
//
//  Colors and styles for UI background
//

import SwiftUI


extension Color {
    static var ohpPrimary: Color {
        Color(red: 0.0157, green: 0.2039, blue: 0.2980)
    }
    static var ohpPrimaryLight: Color {
        Color(red: 0.0078, green: 0.3490, blue: 0.3765)
    }
}

struct OHPBackground: View {
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
