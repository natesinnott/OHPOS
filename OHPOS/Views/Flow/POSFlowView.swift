//
//  POSFlowView.swift
//  OHPOS
//
//  Created by Nate Sinnott on 24/10/2025.
//

import SwiftUI

struct POSFlowView: View {
    @StateObject private var vm = POSViewModel()
    @State private var previousStep: POSStep = .category
    
    var body: some View {
        ZStack {
            OHPBackground()
                .ignoresSafeArea()

            // Determine slide direction based on prior step vs current step
            let isForward = isForwardTransition(from: previousStep, to: vm.step)
            let insertEdge: Edge = isForward ? .trailing : .leading
            let removeEdge: Edge = isForward ? .leading : .trailing

            Group {
                switch vm.step {
                case .category:
                    StepCategoryView(vm: vm)
                        .transition(.asymmetric(insertion: .move(edge: insertEdge), removal: .move(edge: removeEdge)))
                case .artNumber:
                    StepArtNumberView(vm: vm)
                        .transition(.asymmetric(insertion: .move(edge: insertEdge), removal: .move(edge: removeEdge)))
                case .amount:
                    StepAmountView(vm: vm)
                        .transition(.asymmetric(insertion: .move(edge: insertEdge), removal: .move(edge: removeEdge)))
                case .summary:
                    StepSummaryView(vm: vm)
                        .transition(.asymmetric(insertion: .move(edge: insertEdge), removal: .move(edge: removeEdge)))
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
                        .transition(.asymmetric(insertion: .move(edge: insertEdge), removal: .move(edge: removeEdge)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .animation(.easeInOut, value: vm.step) // animate only the step transition, not all descendants
        }
        .safeAreaInset(edge: .top) {
            HStack(spacing: 0) {
                Button {
                    vm.resetStateForNewTransaction()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title3.weight(.semibold))
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)
            }
            .padding(.top, 32)
            .padding(.leading, 12)
        }
        .safeAreaInset(edge: .bottom) {
            StepFooterBar(vm: vm)
        }
        .ignoresSafeArea(.container, edges: [.top])
        .onChange(of: vm.step) { newValue in
            previousStep = newValue
        }
        .tint(Color(red: 0.01, green: 0.35, blue: 0.38))
    }
    private func isForwardTransition(from: POSStep, to: POSStep) -> Bool {
        let order: [POSStep] = [.category, .artNumber, .amount, .summary, .processing, .result]
        guard let fromIndex = order.firstIndex(of: from),
              let toIndex = order.firstIndex(of: to) else { return true }
        return toIndex >= fromIndex
    }
}

#Preview {
    POSFlowView()
}
