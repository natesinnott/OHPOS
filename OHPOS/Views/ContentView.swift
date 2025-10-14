//
//  ContentView.swift
//  OHPOS
//
//  UI using more maintainable elements, Liquid Glass design
//

import SwiftUI
import Combine


@MainActor
struct ContentView: View {
    // MARK: - State
    @StateObject private var vm: POSViewModel
    @State private var currencySymbol: String = "$"

    init() {
        _vm = StateObject(wrappedValue: POSViewModel())
    }

    var body: some View {
        GeometryReader { geo in
            let isPortrait = geo.size.height > geo.size.width
            let sidebarWidth = isPortrait
                ? min(560, max(360, geo.size.width * 0.86))
                : min(760, max(520, geo.size.width * 0.56))
            let containerHeight = isPortrait
                ? min(geo.size.height * 0.92, 860)
                : min(geo.size.height * 0.94, 920)
            ZStack {
                OHPBackground()
                    .ignoresSafeArea()

                HStack {
                    Spacer(minLength: 0)
                    VStack {
                        Spacer(minLength: 0)
                        Sidebar(
                            amountCents: $vm.amountCents,
                            category: $vm.category,
                            currencySymbol: currencySymbol,
                            isCharging: $vm.isCharging,
                            statusMessage: $vm.statusMessage,
                            isPortrait: isPortrait,
                            containerHeight: containerHeight,
                            onCharge: vm.charge
                        )
                        .frame(maxWidth: sidebarWidth)
                        .frame(maxHeight: containerHeight)
                        .padding(.horizontal, isPortrait ? 18 : 24)
                        Spacer(minLength: 0)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 24)

                if let result = vm.result {
                    PaymentResultOverlay(result: result, amountCents: vm.amountCents, currencySymbol: currencySymbol, statusMessage: vm.statusMessage)
                        .transition(.scale.combined(with: .opacity))
                        .zIndex(10)
                }
            }
            .preferredColorScheme(.light)
        }
    }
}

#Preview { @MainActor in ContentView() }
