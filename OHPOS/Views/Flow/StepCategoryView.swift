import SwiftUI

struct StepCategoryView: View {
    @ObservedObject var vm: POSViewModel

    var body: some View {
        ZStack {
            // Centered main content
            VStack(spacing: 20) {
                GlassCard {
                    // Category picker
                    VStack(spacing: 14) {
                        Image("OHPLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 160)
                            .padding(.bottom, 8)
                        Text("Select a Category")
                            .font(.largeTitle.weight(.bold))
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)
                        SegmentedPill(selection: $vm.category)
                            .accessibilityLabel("Category selector")
                            .accessibilityHint("Choose concessions, art, flytrap, or merch")
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(24)
        }
        .onChange(of: vm.category) { newValue in
            if newValue == .art { vm.artNumber = nil }
        }
    }
}

#Preview {
    let vm = POSViewModel()
    return StepCategoryView(vm: vm)
        .frame(width: 600, height: 480)
}
