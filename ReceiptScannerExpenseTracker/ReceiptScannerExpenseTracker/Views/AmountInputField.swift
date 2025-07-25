import SwiftUI

struct AmountInputField: View {
    let placeholder: String
    @Binding var amount: String
    
    var body: some View {
        HStack {
            Text("$")
                .font(.headline)
                .foregroundColor(.secondary)
            
            TextField(placeholder, text: $amount)
                .keyboardType(.decimalPad)
                .font(.headline)
                .multilineTextAlignment(.leading)
            
            if !amount.isEmpty {
                Button(action: {
                    amount = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
                .accessibilityLabel("Clear amount")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

#Preview {
    AmountInputField(placeholder: "0.00", amount: .constant(""))
        .previewLayout(.sizeThatFits)
        .padding()
}