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
        Color(red: 0.02, green: 0.20, blue: 0.30) // #04344c
            .ignoresSafeArea(.all)
    }
}

#Preview { OHPBackground() }
