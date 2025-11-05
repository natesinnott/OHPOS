import SwiftUI

struct StepArtNumberView: View {
    @ObservedObject var vm: POSViewModel


    var body: some View {
        GeometryReader { outer in
            let cardHeight = outer.size.height * 0.92
            let cardWidth = min(1100, max(320, outer.size.width - 48))
            VStack(spacing: 20) {
                // Art number picker
                GlassCard {
                    // Layout constants
                    let rows = 4
                    let columnsCount = 5
                    let gridSpacing: CGFloat = 10
                    let headerReserved: CGFloat = 60   // title height inside the card
                    let footerReserved: CGFloat = 120  // summary + clear row (extra clearance)
                    let verticalInsets: CGFloat = 16   // inner top/bottom padding
                    let horizontalInsets: CGFloat = 16  // inner left/right padding

                    // Compute metrics from the **stable** card size so they don't change mid-transition
                    let gridAvailable = max(0, cardHeight - headerReserved - footerReserved - verticalInsets * 2)
                    let cellHeight = snap(max(52, (gridAvailable - CGFloat(rows - 1) * gridSpacing) / CGFloat(rows)))

                    let availableWidth = max(0, cardWidth - horizontalInsets * 2)
                    let cellWidth = snap(max(72, (availableWidth - CGFloat(columnsCount - 1) * gridSpacing) / CGFloat(columnsCount)))

                    VStack(spacing: 14) {
                        // Header
                        Text("Select Art Number")
                            .font(.largeTitle.weight(.bold))
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)
                            .frame(height: headerReserved, alignment: .center)

                        // Grid of 1–20 selectable buttons (fixed layout to prevent reflow during transitions)
                        let numbers = Array(1...20)
                        let rowsData: [[Int]] = stride(from: 0, to: numbers.count, by: columnsCount).map {
                            Array(numbers[$0 ..< min($0 + columnsCount, numbers.count)])
                        }
                        VStack(spacing: gridSpacing) {
                            ForEach(rowsData, id: \.self) { row in
                                HStack(spacing: gridSpacing) {
                                    ForEach(row, id: \.self) { n in
                                        Button {
                                            vm.artNumber = n
                                        } label: {
                                            let isSelected = (vm.artNumber == n)
                                            Text("\(n)")
                                                .font(.title)
                                                .frame(width: cellWidth, height: cellHeight)
                                                .background(isSelected ? Color(red: 0.01, green: 0.35, blue: 0.38).opacity(0.18) : Color.gray.opacity(0.15))
                                                .foregroundStyle(isSelected ? Color.white : Color.primary)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(isSelected ? Color(red: 0.01, green: 0.35, blue: 0.38) : Color.clear, lineWidth: 2)
                                                )
                                                .cornerRadius(12)
                                                .contentShape(RoundedRectangle(cornerRadius: 12))
                                                .accessibilityValue(isSelected ? "Selected" : "")
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("Art number \(n)")
                                    }
                                }
                            }
                        }
                        .transaction { t in t.disablesAnimations = true }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                        // Current selection summary + Clear
                        HStack {
                            Spacer()
                            Button(role: .none) {
                                vm.artNumber = nil
                            } label: {
                                Label("Clear", systemImage: "eraser")
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                            }
                            .buttonStyle(GlassButtonStyle(isEnabled: vm.artNumber != nil))
                            .tint(.red)
                            .disabled(vm.artNumber == nil)
                            .accessibilityHint("Clear selected art number")
                            .padding(.leading, 12)
                        }
                        .padding(.bottom, 16)
                        .frame(height: footerReserved)
                    }
                    .animation(nil, value: vm.step)
                    .padding(.top, verticalInsets)
                    .padding(.bottom, verticalInsets + 28)
                    .padding(.horizontal, horizontalInsets)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .compositingGroup() // Render as a single layer so the whole card moves together during transitions
                .frame(width: cardWidth, height: cardHeight, alignment: .top) // fixed width + height to freeze layout during transitions
                // Strict masking so nothing renders outside the card while it slides
                .mask(
                    RoundedRectangle(cornerRadius: 24, style: .continuous).inset(by: -8)
                )
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
    

    private func snap(_ v: CGFloat) -> CGFloat {
        let scale = UIScreen.main.scale
        return (v * scale).rounded() / scale
    }
}
