import SwiftUI

struct ExpensesView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Expenses")
                    .font(.largeTitle)
                    .padding()
                
                Spacer()
                
                Text("Your expenses will appear here")
                    .font(.headline)
                
                Spacer()
            }
            .navigationTitle("Expenses")
        }
    }
}

struct ExpensesView_Previews: PreviewProvider {
    static var previews: some View {
        ExpensesView()
    }
}