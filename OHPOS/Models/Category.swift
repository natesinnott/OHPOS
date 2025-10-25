//
//  Category.swift
//  OHPOS
//
//  Created by Nate Sinnott on 14/10/2025.
//

import Foundation


enum Category: String, CaseIterable, Identifiable { 
    case concessions, art, flytrap, merch
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var iconName: String {
        switch self {
        case .concessions: return "takeoutbag.and.cup.and.straw.fill"
        case .art: return "paintpalette.fill"
        case .flytrap: return "leaf.fill"
        case .merch: return "tshirt.fill"
        }
    }
}

enum PaymentResult { case approved, failed }

func displayAmount(_ cents: Int) -> String {
    let v = Double(cents) / 100.0
    return String(format: "%.2f", v)
}
