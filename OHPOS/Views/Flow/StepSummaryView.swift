//
//  StepSummaryView.swift
//  OHPOS
//
//  Created by Nate Sinnott on 24/10/2025.
//


import SwiftUI

struct LabeledValueRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.title2)
            Rectangle()
                .foregroundStyle(.secondary)
                .frame(height: 1)
                .overlay(
                    Rectangle()
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [3]))
                        .foregroundStyle(.secondary)
                )
            Text(value)
                .font(.title2)
                .fontWeight(.medium)
        }
    }
}

struct StepSummaryView: View {
    @ObservedObject var vm: POSViewModel

    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()
                GlassCard {
                    VStack(alignment: .center, spacing: 24) {
                        Text("Confirm Sale")
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)
                        VStack(alignment: .leading, spacing: 20) {
                            LabeledValueRow(
                                label: "Category",
                                value: vm.category?.rawValue.capitalized ?? "—"
                            )
                            if vm.category == .art, let n = vm.artNumber {
                                LabeledValueRow(
                                    label: "Art #",
                                    value: "\(n)"
                                )
                            }
                            LabeledValueRow(
                                label: "Amount",
                                value: "$" + displayAmount(vm.amountCents)
                            )
                        }
                        .padding(.vertical, 20)
                    }
                    .padding(.horizontal, 24)
                    .frame(maxWidth: 600)
                }
                Spacer()
                VStack(spacing: 16) {
                    Button {
                        vm.goNext() // triggers charge()
                    } label: {
                        Label(
                            Backend.shared.isConfigured ? "Charge \(displayAmount(vm.amountCents))" : "API Key Not Configured",
                            systemImage: Backend.shared.isConfigured ? "creditcard" : "exclamationmark.triangle"
                        )
                        .font(.title2.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(GlassButtonStyle(isEnabled: true,
                                                  size: .large,
                                                  respectsLabelFont: true,
                                                  dynamicTypeOverride: .accessibility1))
                    .disabled(vm.isCharging || !Backend.shared.isConfigured)
                    .accessibilityLabel("Charge customer for \(displayAmount(vm.amountCents))")
                    
                    Button {
                        vm.goBack()
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                            .font(.title2.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(GlassButtonStyle(isEnabled: true))
                    .accessibilityHint("Go back to edit amount")
                }
                .frame(maxWidth: 600)
                .padding(.top, 12)
                .dynamicTypeSize(.xSmall ... .accessibility3)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

#Preview {
    let vm = POSViewModel()
    vm.category = .art
    vm.artNumber = 7
    vm.amountCents = 1800
    return StepSummaryView(vm: vm)
        .frame(width: 600, height: 480)
}
