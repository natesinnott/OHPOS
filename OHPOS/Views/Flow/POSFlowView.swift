//
//  POSFlowView.swift
//  OHPOS
//
//  Created by Nate Sinnott on 24/10/2025.
//

import SwiftUI

struct POSFlowView: View {
    @StateObject private var vm = POSViewModel()
    
    var body: some View {
        ZStack {
            OHPBackground()
                .ignoresSafeArea()

            Group {
                switch vm.step {
                case .category:
                    StepCategoryView(vm: vm)
                        .transition(.move(edge: .trailing))
                case .artNumber:
                    StepArtNumberView(vm: vm)
                        .transition(.move(edge: .trailing))
                case .amount:
                    StepAmountView(vm: vm)
                        .transition(.move(edge: .trailing))
                case .summary:
                    StepSummaryView(vm: vm)
                        .transition(.move(edge: .trailing))
                case .processing:
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(2.0)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Processing…")
                            .font(.title2.weight(.semibold))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.black.opacity(0.25))
                            .blur(radius: 10)
                    )
                    .transition(.opacity)
                case .result:
                    StepPaymentResult(vm: vm)
                        .transition(.move(edge: .leading))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .animation(.easeInOut, value: vm.step)
    }
}

#Preview {
    POSFlowView()
}
