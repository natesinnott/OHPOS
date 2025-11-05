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
    }
}

#Preview {
    StepAmountView(vm: POSViewModel())
        .frame(width: 600, height: 480)
}
