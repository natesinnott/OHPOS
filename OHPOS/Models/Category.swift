//
//  Category.swift
//  OHPOS
//
//  Created by Nate Sinnott on 14/10/2025.
//

import Foundation


enum Category: String, CaseIterable, Identifiable { case concessions, merch; var id: String { rawValue }; var label: String { rawValue.capitalized } }

enum PaymentResult { case approved, failed }

func displayAmount(_ cents: Int) -> String {
    let v = Double(cents) / 100.0
    return String(format: "%.2f", v)
}
