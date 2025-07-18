import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
            
            ScanView()
                .tabItem {
                    Label("Scan", systemImage: "camera")
                }
            
            ExpensesView()
                .tabItem {
                    Label("Expenses", systemImage: "list.bullet")
                }
            
            ReportsView()
                .tabItem {
                    Label("Reports", systemImage: "chart.bar")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .accentColor(AppTheme.primaryColor)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}