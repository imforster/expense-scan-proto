//
//  ReceiptScannerExpenseTrackerApp.swift
//  ReceiptScannerExpenseTracker
//
//  Created by Ian Forster (Home) on 2025-07-18.
//

import SwiftUI

@main
struct ReceiptScannerExpenseTrackerApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
