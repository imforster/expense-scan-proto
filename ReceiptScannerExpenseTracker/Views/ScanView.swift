import SwiftUI

struct ScanView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Scan Receipt")
                    .font(.largeTitle)
                    .padding()
                
                Spacer()
                
                Button(action: {
                    // Camera functionality will be implemented in task 2.1
                }) {
                    Image(systemName: "camera.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                        .foregroundColor(AppTheme.primaryColor)
                }
                
                Text("Tap to scan a receipt")
                    .font(.headline)
                    .padding()
                
                Spacer()
            }
            .navigationTitle("Scan Receipt")
        }
    }
}

struct ScanView_Previews: PreviewProvider {
    static var previews: some View {
        ScanView()
    }
}