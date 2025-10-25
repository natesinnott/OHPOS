//
//  SegmentedPill.swift
//  OHPOS
//
//  Created by Nate Sinnott on 24/10/2025.
//

import SwiftUI

struct SegmentedPill: View {
    @Binding var selection: Category?
    var body: some View {
        HStack(spacing: 12) {
            ForEach(Category.allCases) { item in
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { selection = item }
                } label: {
                    CategoryTile(item: item, isSelected: selection == item)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
    }
}

private struct CategoryTile: View {
    @Environment(\.colorScheme) private var colorScheme
    let item: Category
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: item.iconName)
                .font(.system(size: 28, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)

            Text(item.label)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding(.vertical, 16)
        .padding(.bottom, 8)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(colorScheme == .light ? .regularMaterial : .thinMaterial)
                .opacity(isSelected ? 1 : 0.4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(isSelected ? 0.9 : 0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(colorScheme == .light ? 0.10 : 0.20), radius: isSelected ? 10 : 4, y: isSelected ? 4 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(item.label))
        .accessibilityHint(isSelected ? "Selected" : "Double-tap to select")
    }
}
