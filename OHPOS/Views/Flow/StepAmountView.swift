//
//  StepAmountView.swift
//  OHPOS
//
//  Created by Nate Sinnott on 24/10/2025.
//

import SwiftUI

struct StepAmountView: View {
    @ObservedObject var vm: POSViewModel

    var body: some View {
        ZStack {
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    GlassCard {
                        VStack(spacing: 16) {
                            // Header
                            Text("Enter Amount")
                                .font(.largeTitle.weight(.bold))
                                .multilineTextAlignment(.center)
                                .accessibilityAddTraits(.isHeader)

                            // Subtitle showing category and art number if relevant
                            if let cat = vm.category {
                                Text(cat == .art ? "Art #\(vm.artNumber ?? 0)" : cat.rawValue.capitalized)
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }

                            // Keypad
                            AmountKeypad(amountCents: $vm.amountCents)
                                .frame(maxHeight: 600)
                                .accessibilityLabel("Numeric keypad")
                                .padding(.top, 8)

                        }
                        .frame(maxWidth: 900)
                    }
                    .frame(maxWidth: 1100)
                    .frame(height: proxy.size.height * 0.92, alignment: .top)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(24)
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Button { vm.goBack() } label: {
                    Label("Back", systemImage: "chevron.left")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(GlassButtonStyle(isEnabled: true))
                .accessibilityHint("Go back to previous step")

                Button { vm.goNext() } label: {
                    Label("Continue", systemImage: "chevron.right")
                        .labelStyle(TrailingIconLabelStyle())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(GlassButtonStyle(isEnabled: vm.canContinueFromAmount))
                .disabled(!vm.canContinueFromAmount)
                .accessibilityLabel("Continue to summary screen")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
    }
}

#Preview {
    StepAmountView(vm: POSViewModel())
        .frame(width: 600, height: 480)
}
