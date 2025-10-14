//
//  AmountKeypad.swift
//  OHPOS
//
//  Created by Nate Sinnott on 14/10/2025.
//

import SwiftUI

struct AmountKeypad: View {
    @Binding var amountCents: Int
    var body: some View {
        VStack(spacing: 12) {
            Text(displayAmount(amountCents)).font(.system(size:48, weight: .bold, design: .rounded))
            let rows = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["C", "0", "⌫"]]
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 12) {
                    ForEach(row, id: \.self) { key in
                        Button {
                            tap(key)
                        } label: {
                            Text(key).font(.title).frame(maxWidth: .infinity).padding().background(Color.gray.opacity(0.15)).cornerRadius(12)
                        }
                    }
                }
            }
        }
    }
    
    private func tap(_ key: String) {
        switch key {
        case "C": amountCents = 0
        case "⌫": amountCents /= 10
        default:
            if let d = Int(key) {
                if amountCents < 9_999_999 { amountCents = min(amountCents * 10 + d, 9_999_999) }
            }
        }
    }
    
    private func displayAmount(_ cents: Int) -> String {
        let v = Double(cents) / 100.0
        return String(format: "$%.2f", v)
    }
}
