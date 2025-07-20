import SwiftUI
import Foundation

struct ReceiptReviewView: View {
    @StateObject private var viewModel: ReceiptReviewViewModel
    @Environment(\.dismiss) private var dismiss
    
    let onSaveComplete: (() -> Void)?
    
    init(receiptData: ReceiptData, originalImage: UIImage, onSaveComplete: (() -> Void)? = nil) {
        self._viewModel = StateObject(wrappedValue: ReceiptReviewViewModel(receiptData: receiptData, originalImage: originalImage))
        self.onSaveComplete = onSaveComplete
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Receipt Image Preview
                    receiptImageSection
                    
                    // Confidence Indicator
                    confidenceIndicatorSection
                    
                    // Editable Fields
                    editableFieldsSection
                    
                    // Items Section
                    if !viewModel.items.isEmpty {
                        itemsSection
                    }
                    
                    // Action Buttons
                    actionButtonsSection
                }
                .padding()
            }
            .navigationTitle("Review Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Validation Error", isPresented: $viewModel.showValidationError) {
                Button("OK") { }
            } message: {
                Text(viewModel.validationErrorMessage)
            }
            .alert("Save Successful", isPresented: $viewModel.showSaveSuccess) {
                Button("OK") {
                    // Call the completion callback to dismiss the entire flow
                    onSaveComplete?()
                    dismiss()
                }
            } message: {
                Text("Receipt has been saved successfully!")
            }
            .alert("Confirm Save", isPresented: $viewModel.showConfirmation) {
                Button("Save Anyway", role: .destructive) {
                    viewModel.confirmSave()
                }
                Button("Review Again", role: .cancel) {
                    viewModel.cancelSave()
                }
            } message: {
                Text("Some fields have low confidence scores. Please review the highlighted fields before saving, or save anyway if the information looks correct.")
            }
            .alert("Unsaved Changes", isPresented: .constant(false)) {
                Button("Discard Changes", role: .destructive) {
                    dismiss()
                }
                Button("Keep Editing", role: .cancel) { }
            } message: {
                Text("You have unsaved changes. Are you sure you want to leave?")
            }
        }
    }
    
    // MARK: - View Components
    
    private var receiptImageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Receipt Image")
                .font(.headline)
                .foregroundColor(.primary)
            
            ZStack {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(width: 200, height: 300)
                    .cornerRadius(8)
                
                Image(uiImage: viewModel.originalImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .rotationEffect(.degrees(90))
                    .scaleEffect(x: -1, y: 1)
                    .frame(maxWidth: 200, maxHeight: 300)
            }
            .cornerRadius(8)
            .shadow(radius: 2)
        }
    }
    
    private var confidenceIndicatorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Extraction Confidence")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack {
                ProgressView(value: viewModel.overallConfidence, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: confidenceColor))
                
                Text("\(Int(viewModel.overallConfidence * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(confidenceColor)
            }
            
            Text(confidenceDescription)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private var editableFieldsSection: some View {
        VStack(spacing: 16) {
            Text("Receipt Details")
                .font(.headline)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Merchant Name
            EditableFieldView(
                title: "Merchant",
                text: $viewModel.merchantName,
                isHighlighted: viewModel.shouldHighlightMerchant,
                placeholder: "Enter merchant name",
                validation: viewModel.validateMerchantName
            )
            
            // Date
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Date")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if viewModel.shouldHighlightDate {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                }
                
                DatePicker("Receipt Date", selection: $viewModel.date, displayedComponents: .date)
                    .datePickerStyle(CompactDatePickerStyle())
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(viewModel.shouldHighlightDate ? Color.orange : Color.clear, lineWidth: 2)
                    )
            }
            
            // Total Amount
            EditableFieldView(
                title: "Total Amount",
                text: $viewModel.totalAmountText,
                isHighlighted: viewModel.shouldHighlightTotal,
                placeholder: "0.00",
                keyboardType: .decimalPad,
                validation: viewModel.validateTotalAmount
            )
            
            // Tax Amount
            EditableFieldView(
                title: "Tax Amount (Optional)",
                text: $viewModel.taxAmountText,
                isHighlighted: viewModel.shouldHighlightTax,
                placeholder: "0.00",
                keyboardType: .decimalPad,
                validation: viewModel.validateTaxAmount
            )
            
            // Payment Method
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Payment Method")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if viewModel.shouldHighlightPaymentMethod {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                }
                
                Picker("Payment Method", selection: $viewModel.paymentMethod) {
                    Text("Unknown").tag(nil as String?)
                    ForEach(PaymentMethod.allCases, id: \.self) { method in
                        Text(method.displayName).tag(method.rawValue as String?)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(viewModel.shouldHighlightPaymentMethod ? Color.orange : Color.clear, lineWidth: 2)
                )
            }
            
            // Receipt Number
            EditableFieldView(
                title: "Receipt Number (Optional)",
                text: $viewModel.receiptNumber,
                isHighlighted: viewModel.shouldHighlightReceiptNumber,
                placeholder: "Enter receipt number",
                validation: viewModel.validateReceiptNumber
            )
        }
    }
    
    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Items")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Add Item") {
                    viewModel.addNewItem()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            ForEach(viewModel.items.indices, id: \.self) { index in
                ItemEditView(
                    item: $viewModel.items[index],
                    onDelete: {
                        viewModel.removeItem(at: index)
                    }
                )
            }
        }
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // Validation Summary
            if !viewModel.validationErrors.isEmpty {
                validationSummarySection
            }
            
            // Save Button
            Button(action: {
                viewModel.saveReceipt()
            }) {
                HStack {
                    if viewModel.isSaving {
                        ProgressView()
                            .scaleEffect(0.8)
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: viewModel.isValid ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    }
                    Text(saveButtonText)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(saveButtonColor)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(viewModel.isSaving)
            
            // Rescan Button
            Button("Rescan Receipt") {
                viewModel.rescanReceipt()
                dismiss()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray5))
            .foregroundColor(.primary)
            .cornerRadius(10)
        }
    }
    
    private var validationSummarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("Validation Issues")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.red)
            }
            
            ForEach(Array(viewModel.validationErrors.keys.sorted()), id: \.self) { key in
                if let error = viewModel.validationErrors[key] {
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var saveButtonText: String {
        if viewModel.isSaving {
            return "Saving..."
        } else if !viewModel.isValid {
            return "Fix Errors to Save"
        } else {
            return "Save Receipt"
        }
    }
    
    private var saveButtonColor: Color {
        if viewModel.isSaving {
            return .blue
        } else if !viewModel.isValid {
            return .gray
        } else {
            return .blue
        }
    }
    
    // MARK: - Computed Properties
    
    private var confidenceColor: Color {
        switch viewModel.overallConfidence {
        case 0.8...1.0:
            return .green
        case 0.5..<0.8:
            return .orange
        default:
            return .red
        }
    }
    
    private var confidenceDescription: String {
        switch viewModel.overallConfidence {
        case 0.8...1.0:
            return "High confidence - Most fields were extracted accurately"
        case 0.5..<0.8:
            return "Medium confidence - Please review highlighted fields"
        default:
            return "Low confidence - Please verify all fields carefully"
        }
    }
}

// MARK: - Supporting Views

struct EditableFieldView: View {
    let title: String
    @Binding var text: String
    let isHighlighted: Bool
    let placeholder: String
    var keyboardType: UIKeyboardType = .default
    let validation: (String) -> String?
    
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if isHighlighted {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
                
                Spacer()
                
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            TextField(placeholder, text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(keyboardType)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(strokeColor, lineWidth: 2)
                )
                .onChange(of: text) { newValue in
                    errorMessage = validation(newValue)
                }
        }
    }
    
    private var strokeColor: Color {
        if let _ = errorMessage {
            return .red
        } else if isHighlighted {
            return .orange
        } else {
            return .clear
        }
    }
}

struct ItemEditView: View {
    @Binding var item: ReceiptItemEditModel
    let onDelete: () -> Void
    
    @State private var nameError: String?
    @State private var quantityError: String?
    @State private var priceError: String?
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Item")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                if hasErrors {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
            
            VStack(spacing: 8) {
                // Item Name
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Item name", text: $item.name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(nameError != nil ? Color.red : Color.clear, lineWidth: 2)
                        )
                        .onChange(of: item.name) { newValue in
                            nameError = validateItemName(newValue)
                        }
                    
                    if let error = nameError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                HStack(spacing: 12) {
                    // Quantity
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Qty", text: $item.quantityText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                            .frame(width: 80)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(quantityError != nil ? Color.red : Color.clear, lineWidth: 2)
                            )
                            .onChange(of: item.quantityText) { newValue in
                                quantityError = validateQuantity(newValue)
                            }
                        
                        if let error = quantityError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .frame(width: 80)
                        }
                    }
                    
                    // Price
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Price", text: $item.priceText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.decimalPad)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(priceError != nil ? Color.red : Color.clear, lineWidth: 2)
                            )
                            .onChange(of: item.priceText) { newValue in
                                priceError = validatePrice(newValue)
                            }
                        
                        if let error = priceError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
        }
        .padding()
        .background(hasErrors ? Color.red.opacity(0.05) : Color(.systemGray6))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(hasErrors ? Color.red.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .onAppear {
            // Validate initial values
            nameError = validateItemName(item.name)
            quantityError = validateQuantity(item.quantityText)
            priceError = validatePrice(item.priceText)
        }
    }
    
    private var hasErrors: Bool {
        return nameError != nil || quantityError != nil || priceError != nil
    }
    
    private func validateItemName(_ name: String) -> String? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedName.isEmpty {
            return "Name required"
        }
        
        if trimmedName.count > 100 {
            return "Name too long"
        }
        
        return nil
    }
    
    private func validateQuantity(_ quantityText: String) -> String? {
        let trimmedQuantity = quantityText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedQuantity.isEmpty {
            return "Qty required"
        }
        
        guard let quantity = Int(trimmedQuantity) else {
            return "Invalid qty"
        }
        
        if quantity <= 0 {
            return "Qty > 0"
        }
        
        if quantity > 999 {
            return "Qty too high"
        }
        
        return nil
    }
    
    private func validatePrice(_ priceText: String) -> String? {
        let trimmedPrice = priceText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedPrice.isEmpty {
            return "Price required"
        }
        
        let decimalRegex = "^\\d+(\\.\\d{1,2})?$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", decimalRegex)
        if !predicate.evaluate(with: trimmedPrice) {
            return "Invalid price"
        }
        
        guard let price = Decimal(string: trimmedPrice) else {
            return "Invalid price"
        }
        
        if price <= 0 {
            return "Price > 0"
        }
        
        if price > 99999.99 {
            return "Price too high"
        }
        
        return nil
    }
}

// MARK: - Supporting Types

enum PaymentMethod: String, CaseIterable {
    case cash = "Cash"
    case credit = "Credit"
    case debit = "Debit"
    case visa = "Visa"
    case mastercard = "Mastercard"
    case amex = "Amex"
    case discover = "Discover"
    case other = "Other"
    
    var displayName: String {
        return rawValue
    }
}

struct ReceiptItemEditModel {
    var name: String
    var quantityText: String
    var priceText: String
    
    var quantity: Int? {
        Int(quantityText)
    }
    
    var price: Decimal? {
        Decimal(string: priceText)
    }
    
    init(from item: ReceiptItemData) {
        self.name = item.name
        self.quantityText = item.quantity?.description ?? "1"
        self.priceText = item.totalPrice.description
    }
    
    init() {
        self.name = ""
        self.quantityText = "1"
        self.priceText = "0.00"
    }
}

#Preview {
    ReceiptReviewView(
        receiptData: ReceiptData(
            merchantName: "Sample Store",
            date: Date(),
            totalAmount: Decimal(25.99),
            taxAmount: Decimal(2.08),
            items: [
                ReceiptItemData(name: "Coffee", quantity: 1, unitPrice: Decimal(4.99), totalPrice: Decimal(4.99)),
                ReceiptItemData(name: "Sandwich", quantity: 1, unitPrice: Decimal(8.99), totalPrice: Decimal(8.99))
            ],
            paymentMethod: "Visa",
            receiptNumber: "12345",
            confidence: 0.85
        ),
        originalImage: UIImage(systemName: "doc.text") ?? UIImage()
    )
}