import SwiftUI

struct DashboardView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Dashboard")
                    .font(.largeTitle)
                    .padding()
                
                Spacer()
                
                Text("Welcome to Receipt Scanner Expense Tracker")
                    .font(.headline)
                
                Spacer()
            }
            .navigationTitle("Dashboard")
        }
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
    }
}