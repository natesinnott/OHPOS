//
//  StepFooterBar.swift
//  OHPOS
//
//  Created by Nate Sinnott on 25/10/2025.
//

import SwiftUI

struct StepFooterBar: View {
    @ObservedObject var vm: POSViewModel
    
    @State private var localPrevStep: POSStep = .category
    @State private var isExitingLeft: Bool = false
    @Namespace private var footerNS
    
    private var slideWidth: CGFloat { UIScreen.main.bounds.width }
    
    var body: some View {
        Group {
            switch vm.step {
            case .category:
                HStack(spacing: 12) {
                    Spacer()
                    continueContainer(
                        title: "Continue",
                        icon: "chevron.right",
                        isEnabled: vm.canContinueFromCategory,
                        action: {
                            if vm.category == .art { vm.artNumber = nil }
                            vm.goNext()
                        }
                    )
                    Spacer()
                }

            case .artNumber:
                HStack(spacing: 12) {
                    backButton(action: { vm.goBack() })
                        .frame(maxWidth: UIScreen.main.bounds.width / 3)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    Spacer(minLength: 0)
                    continueContainer(
                        title: "Continue",
                        icon: "chevron.right",
                        isEnabled: vm.step == .artNumber ? vm.canContinueFromArtNumber : vm.canContinueFromAmount,
                        action: { vm.goNext() },
                        maxWidth: UIScreen.main.bounds.width * 2 / 3
                    )
                }
                .offset(x: isExitingLeft ? -slideWidth : 0)

            case .amount:
                HStack(spacing: 12) {
                    backButton(action: { vm.goBack() })
                        .frame(maxWidth: UIScreen.main.bounds.width / 3)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    Spacer(minLength: 0)
                    continueContainer(
                        title: "Continue",
                        icon: "chevron.right",
                        isEnabled: vm.step == .artNumber ? vm.canContinueFromArtNumber : vm.canContinueFromAmount,
                        action: { vm.goNext() },
                        maxWidth: UIScreen.main.bounds.width * 2 / 3
                    )
                }
                .offset(x: isExitingLeft ? -slideWidth : 0)

            case .summary:
                EmptyView() // footer hidden on summary; summary has its own actions

            case .processing, .result:
                EmptyView() // no footer on overlays
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color.clear)
        .animation(.easeInOut(duration: 0.28), value: vm.step)
        .animation(.easeInOut(duration: 0.28), value: isExitingLeft)
        .onChange(of: vm.step) { newValue in
            // If leaving Amount for Summary, briefly slide the buttons off the left
            if localPrevStep == .amount && newValue == .summary {
                isExitingLeft = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
                    isExitingLeft = false
                }
            }
            localPrevStep = newValue
        }
    }

    private func backButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label("Back", systemImage: "chevron.left")
                .frame(maxWidth: 200)
                .padding(.vertical, 12)
        }
        .buttonStyle(GlassButtonStyle(isEnabled: true))
    }

    private func continueButton(title: String, icon: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .labelStyle(TrailingIconLabelStyle())
                .padding(.vertical, 12)
        }
        .buttonStyle(GlassButtonStyle(isEnabled: isEnabled))
        .disabled(!isEnabled)
    }

    private func continueContainer(title: String, icon: String, isEnabled: Bool, action: @escaping () -> Void, maxWidth: CGFloat? = nil) -> some View {
        // Stable layout container so matchedGeometryEffect morphs instead of crossfading
        VStack(spacing: 0) {
            continueButton(title: title, icon: icon, isEnabled: isEnabled, action: action)
                .contentTransition(.identity)
                .matchedGeometryEffect(id: "continue", in: footerNS)
                .frame(height: 48)
        }
        .frame(maxWidth: maxWidth ?? .infinity)
    }
}
