//
//  Sidebar.swift
//  OHPOS
//
//  Main UI element construction
//

import SwiftUI


struct Sidebar: View {
    @Binding var amountCents: Int
    @Binding var category: Category?
    let currencySymbol: String
    @Binding var isCharging: Bool
    @Binding var statusMessage: String
    let isPortrait: Bool
    let containerHeight: CGFloat
    var onCharge: () -> Void

    private var keypadHeight: CGFloat {
        // Reserve space for header and footer explicitly.
        // Portrait was previously good — keep it generous but bounded.
        let reservedTop: CGFloat = isPortrait ? 330 : 210
        let reservedBottom: CGFloat = isPortrait ? 200 : 190
        let available = max(240, containerHeight - reservedTop - reservedBottom)

        if isPortrait {
            // Portrait: allow a larger keypad and push the charge/status card down
            return max(460, min(available, 640))
        } else {
            // Landscape: shorter keys so the footer always fits
            return max(340, min(available, 460))
        }
    }

    private var chargeButtonText: String {
        if amountCents == 0 { return "Enter Amount" }
        if category == nil { return "Select Concessions or Merch" }
        return "Charge \(currencySymbol)\(displayAmount(amountCents))"
    }

    private var chargeButtonIconName: String {
        if isCharging { return "hourglass" }                 // shows during processing
        if amountCents == 0 { return "dollarsign.circle" }       // prompt to enter amount
        if category == nil { return "hand.point.up.left" }      // prompt to pick a type
        return "creditcard.and.123"                           // ready to charge
    }

    var body: some View {
        VStack(alignment: .center, spacing: isPortrait ? 20 : 16) {
            HStack {
                Spacer(minLength: 0)
                HeaderLogo()
                    .frame(height: 64)
                Spacer(minLength: 0)
            }

            

            Text("\(currencySymbol)\(displayAmount(amountCents))")
                .font(.system(size: 54, weight: .heavy, design: .rounded))
                .accessibilityLabel("Amount")
                .accessibilityValue("\(currencySymbol)\(displayAmount(amountCents))")
                .padding(.top, 4)

            GlassCard {
                Keypad(amountCents: $amountCents, currencySymbol: currencySymbol, isPortrait: isPortrait)
            }
            .frame(height: keypadHeight)
            .animation(.easeInOut(duration: 0.2), value: keypadHeight)
            
            SegmentedPill(selection: $category)

            GlassCard {
                VStack(spacing: 10) {
                    Button(action: onCharge) {
                        HStack {
                            Image(systemName: chargeButtonIconName)
                            Text(chargeButtonText)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(GlassButtonStyle(isEnabled: amountCents > 0 && (category != nil) && !isCharging))
                    .disabled((amountCents == 0) || (category == nil) || isCharging)
                    .accessibilityLabel(chargeButtonText)
                    .accessibilityHint("Start card payment")


                    Text("Status: \(statusMessage)")
                        .font(.footnote.weight(.medium))
                        .foregroundColor(.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .accessibilityLabel("Status")
                        .accessibilityValue(statusMessage)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
}

// MARK: - Components & Styles
struct HeaderLogo: View {
    var body: some View {
        if let _ = UIImage(named: "OHPLogo") {
            Image("OHPLogo")
                .resizable()
                .scaledToFit()
                .frame(height: 60)
        } else {
            Image(systemName: "theatermasks.fill")
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
        }
    }
}

struct SegmentedPill: View {
    @Binding var selection: Category?
    var body: some View {
        HStack(spacing: 8) {
            ForEach(Category.allCases) { item in
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { selection = item }
                } label: {
                    Text(item.label)
                        .font(.subheadline.weight(.semibold))
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(.thinMaterial)
                                .opacity(selection == item ? 1 : 0)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
}

struct GlassCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        content
            .padding(16)                                 // internal padding
            .background(shape.fill(.ultraThinMaterial))  // glass behind content
            .overlay(shape.stroke(Color.white.opacity(0.35), lineWidth: 0.5))
            .clipShape(shape)                            // keep content inside rounded rect
    }
}
