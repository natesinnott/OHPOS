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
        // Footer pinned to bottom without affecting layout height
        .overlay(alignment: .bottom) {
            HStack(spacing: 12) {
                Button { vm.goBack() } label: {
                    Label("Back", systemImage: "chevron.left")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(GlassButtonStyle(isEnabled: false))
                .disabled(true)
                .accessibilityHint("You're on the first step")

                Button {
                    if vm.category == .art { vm.artNumber = nil }
                    vm.goNext()
                } label: {
                    Label("Continue", systemImage: "chevron.right")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .labelStyle(TrailingIconLabelStyle())
                }
                .buttonStyle(GlassButtonStyle(isEnabled: vm.canContinueFromCategory))
                .disabled(!vm.canContinueFromCategory)
                .accessibilityLabel("Continue to next step")
                .accessibilityHint(vm.category == .art ? "Next you'll pick the art number" : "Next you'll enter the amount")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .safeAreaPadding(.bottom)
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
