import SwiftUI

@main
struct ReceiptScannerExpenseTrackerApp: App {
    @StateObject private var coreDataManager = CoreDataManager.shared
    
    init() {
        // Configure app appearance
        configureAppAppearance()
        
        // Enable data protection
        coreDataManager.enableDataProtection()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, coreDataManager.viewContext)
                .accentColor(AppTheme.primaryColor)
                .preferredColorScheme(.light)
        }
    }
    
    private func configureAppAppearance() {
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(AppTheme.backgroundColor)
        appearance.titleTextAttributes = [.foregroundColor: UIColor(AppTheme.primaryColor)]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(AppTheme.primaryColor)]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        // Configure tab bar appearance
        UITabBar.appearance().backgroundColor = UIColor(AppTheme.backgroundColor)
        UITabBar.appearance().unselectedItemTintColor = UIColor.gray
        UITabBar.appearance().tintColor = UIColor(AppTheme.primaryColor)
    }
}