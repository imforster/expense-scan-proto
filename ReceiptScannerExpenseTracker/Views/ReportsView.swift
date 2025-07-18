import SwiftUI

struct ReportsView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Reports")
                    .font(.largeTitle)
                    .padding()
                
                Spacer()
                
                Text("Your expense reports will appear here")
                    .font(.headline)
                
                Spacer()
            }
            .navigationTitle("Reports")
        }
    }
}

struct ReportsView_Previews: PreviewProvider {
    static var previews: some View {
        ReportsView()
    }
}