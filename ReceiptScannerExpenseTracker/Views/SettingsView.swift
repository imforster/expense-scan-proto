import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("App Settings")) {
                    Text("Settings options will appear here")
                }
                
                Section(header: Text("Account")) {
                    Text("Account settings will appear here")
                }
                
                Section(header: Text("About")) {
                    Text("Receipt Scanner Expense Tracker")
                    Text("Version 1.0")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}