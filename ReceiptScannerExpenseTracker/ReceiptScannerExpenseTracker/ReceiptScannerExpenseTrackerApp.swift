//
//  ReceiptScannerExpenseTrackerApp.swift
//  ReceiptScannerExpenseTracker
//
//  Created by Ian Forster (Home) on 2025-07-18.
//

import SwiftUI

@main
struct ReceiptScannerExpenseTrackerApp: App {
    @StateObject private var coreDataManager = CoreDataManager.shared
    @StateObject private var themeManager = ThemeManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, coreDataManager.viewContext)
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.colorScheme)
        }
    }
}
