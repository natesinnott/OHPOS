//
//  OHPOSApp.swift
//  OHPOS
//
//  Created by Nate Sinnott on 14/10/2025.
//

import SwiftUI

@main
struct OHPOSApp: App {
    init() {
        Backend.shared.debugPOSKeySource()
    }
    var body: some Scene {
        WindowGroup {
            POSFlowView()
        }
    }
}
