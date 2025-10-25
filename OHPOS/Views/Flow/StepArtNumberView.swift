import SwiftUI

struct StepArtNumberView: View {
    @ObservedObject var vm: POSViewModel
    private let numberColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)

    var body: some View {
        VStack(spacing: 20) {
            // Header


            // Art number picker
            GlassCard {
                GeometryReader { proxy in
                    // Layout constants
                    let rows = 4
                    let gridSpacing: CGFloat = 10
                    let headerReserved: CGFloat = 60   // title height inside the card
                    let footerReserved: CGFloat = 52   // summary + clear row
                    let verticalInsets: CGFloat = 16   // inner top/bottom padding

                    // Compute tall button height to fill space evenly
                    let gridAvailable = max(0, proxy.size.height - headerReserved - footerReserved - verticalInsets * 2)
                    let cellHeight = max(52, (gridAvailable - CGFloat(rows - 1) * gridSpacing) / CGFloat(rows))

                    VStack(spacing: 14) {
                        // Header
                        Text("Select Art Number")
                            .font(.largeTitle.weight(.bold))
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)
                            .frame(height: headerReserved, alignment: .center)

                        // Grid of 1–20 selectable buttons
                        LazyVGrid(columns: numberColumns, alignment: .center, spacing: gridSpacing) {
                            ForEach(1...20, id: \.self) { n in
                                Button {
                                    vm.artNumber = n
                                } label: {
                                    Text("\(n)")
                                        .font(.title)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.plain)
                                .frame(height: cellHeight)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(vm.artNumber == n ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.15))
                                )
                                .foregroundStyle(vm.artNumber == n ? Color.accentColor : Color.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .contentShape(RoundedRectangle(cornerRadius: 12))
                                .accessibilityLabel("Art number \(n)")
                                .accessibilityAddTraits(vm.artNumber == n ? .isSelected : [])
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                        // Current selection summary + Clear
                        HStack {
                            if let current = vm.artNumber {
                                Label("Selected: # \(current)", systemImage: "checkmark.circle.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                Label("No number selected", systemImage: "circle")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(role: .none) {
                                vm.artNumber = nil
                            } label: {
                                Label("Clear", systemImage: "eraser")
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                            }
                            .buttonStyle(GlassButtonStyle(isEnabled: vm.artNumber != nil))
                            .disabled(vm.artNumber == nil)
                            .accessibilityHint("Clear selected art number")
                            .padding(.leading, 12)
                        }
                        .frame(height: footerReserved)
                    }
                    .padding(.vertical, verticalInsets)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
            .frame(maxHeight: .infinity)

            Spacer(minLength: 0)

            // Footer controls
            HStack(spacing: 12) {
                Button {
                    vm.goBack()
                } label: {
                    Label("Back", systemImage: "chevron.left")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(GlassButtonStyle(isEnabled: true))
                .accessibilityHint("Go back to category selection")

                Button {
                    vm.goNext()
                } label: {
                    Label("Continue", systemImage: "chevron.right")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .labelStyle(TrailingIconLabelStyle())
                }
                .buttonStyle(GlassButtonStyle(isEnabled: vm.canContinueFromArtNumber))
                .disabled(!vm.canContinueFromArtNumber)
                .accessibilityLabel("Continue to amount entry")
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

#Preview {
    let vm = POSViewModel()
    vm.category = .art
    return StepArtNumberView(vm: vm)
        .frame(width: 600, height: 480)
}
