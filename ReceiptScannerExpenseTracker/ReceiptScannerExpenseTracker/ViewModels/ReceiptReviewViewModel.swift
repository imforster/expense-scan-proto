import SwiftUI
import Foundation
import CoreData
import Combine

@MainActor
class ReceiptReviewViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var merchantName: String = ""
    @Published var date: Date = Date()
    @Published var totalAmountText: String = ""
    @Published var taxAmountText: String = ""
    @Published var paymentMethod: String?
    @Published var receiptNumber: String = ""
    @Published var items: [ReceiptItemEditModel] = []
    
    @Published var isSaving: Bool = false
    @Published var showValidationError: Bool = false
    @Published var showSaveSuccess: Bool = false
    @Published var showConfirmation: Bool = false
    @Published var validationErrorMessage: String = ""
    @Published var validationErrors: [String: String] = [:]
    @Published var hasUnsavedChanges: Bool = false
    
    // MARK: - Private Properties
    private let originalReceiptData: ReceiptData
    let originalImage: UIImage
    private let coreDataManager = CoreDataManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    var overallConfidence: Float {
        return originalReceiptData.confidence
    }
    
    var shouldHighlightMerchant: Bool {
        let confidence = fieldConfidenceScores["merchantName"] ?? 0.0
        return confidence < 0.6 || validateMerchantName(merchantName) != nil
    }
    
    var shouldHighlightDate: Bool {
        return overallConfidence < 0.7
    }
    
    var shouldHighlightTotal: Bool {
        let confidence = fieldConfidenceScores["totalAmount"] ?? 0.0
        return confidence < 0.6 || validateTotalAmount(totalAmountText) != nil
    }
    
    var shouldHighlightTax: Bool {
        let confidence = fieldConfidenceScores["taxAmount"] ?? 0.0
        return (confidence < 0.5 && !taxAmountText.isEmpty) || validateTaxAmount(taxAmountText) != nil
    }
    
    var shouldHighlightPaymentMethod: Bool {
        let confidence = fieldConfidenceScores["paymentMethod"] ?? 0.0
        return confidence < 0.5
    }
    
    var shouldHighlightReceiptNumber: Bool {
        let confidence = fieldConfidenceScores["receiptNumber"] ?? 0.0
        return confidence < 0.4 || validateReceiptNumber(receiptNumber) != nil
    }
    
    var isValid: Bool {
        let errors = validateAllFields()
        return errors.isEmpty
    }
    
    var fieldConfidenceScores: [String: Float] {
        // Calculate individual field confidence scores based on OCR confidence and field-specific factors
        var scores: [String: Float] = [:]
        
        scores["merchantName"] = calculateFieldConfidence(
            baseConfidence: overallConfidence,
            fieldValue: merchantName,
            isEmpty: merchantName.isEmpty || merchantName == "Unknown Merchant"
        )
        
        scores["totalAmount"] = calculateFieldConfidence(
            baseConfidence: overallConfidence,
            fieldValue: totalAmountText,
            isEmpty: totalAmountText.isEmpty
        )
        
        scores["taxAmount"] = calculateFieldConfidence(
            baseConfidence: overallConfidence,
            fieldValue: taxAmountText,
            isEmpty: taxAmountText.isEmpty
        )
        
        scores["paymentMethod"] = calculateFieldConfidence(
            baseConfidence: overallConfidence,
            fieldValue: paymentMethod ?? "",
            isEmpty: paymentMethod == nil
        )
        
        scores["receiptNumber"] = calculateFieldConfidence(
            baseConfidence: overallConfidence,
            fieldValue: receiptNumber,
            isEmpty: receiptNumber.isEmpty
        )
        
        return scores
    }
    
    private func calculateFieldConfidence(baseConfidence: Float, fieldValue: String, isEmpty: Bool) -> Float {
        if isEmpty {
            return 0.0
        }
        
        // Adjust confidence based on field characteristics
        var adjustedConfidence = baseConfidence
        
        // Reduce confidence for very short values (likely extraction errors)
        if fieldValue.count < 3 {
            adjustedConfidence *= 0.7
        }
        
        // Reduce confidence for values with unusual characters
        let hasUnusualChars = fieldValue.rangeOfCharacter(from: CharacterSet.alphanumerics.union(.whitespaces).union(.punctuationCharacters).inverted) != nil
        if hasUnusualChars {
            adjustedConfidence *= 0.5
        }
        
        return min(adjustedConfidence, 1.0)
    }
    
    // MARK: - Initialization
    init(receiptData: ReceiptData, originalImage: UIImage) {
        self.originalReceiptData = receiptData
        self.originalImage = originalImage
        
        setupInitialValues()
    }
    
    // MARK: - Setup Methods
    private func setupInitialValues() {
        merchantName = originalReceiptData.merchantName
        date = originalReceiptData.date
        totalAmountText = originalReceiptData.totalAmount.description
        taxAmountText = originalReceiptData.taxAmount?.description ?? ""
        paymentMethod = originalReceiptData.paymentMethod
        receiptNumber = originalReceiptData.receiptNumber ?? ""
        
        // Setup items
        if let receiptItems = originalReceiptData.items {
            items = receiptItems.map { ReceiptItemEditModel(from: $0) }
        }
        
        // Setup change tracking
        setupChangeTracking()
    }
    
    private func setupChangeTracking() {
        // Track changes to detect unsaved modifications
        $merchantName
            .dropFirst()
            .sink { [weak self] _ in
                self?.hasUnsavedChanges = true
            }
            .store(in: &cancellables)
        
        $date
            .dropFirst()
            .sink { [weak self] _ in
                self?.hasUnsavedChanges = true
            }
            .store(in: &cancellables)
        
        $totalAmountText
            .dropFirst()
            .sink { [weak self] _ in
                self?.hasUnsavedChanges = true
            }
            .store(in: &cancellables)
        
        $taxAmountText
            .dropFirst()
            .sink { [weak self] _ in
                self?.hasUnsavedChanges = true
            }
            .store(in: &cancellables)
        
        $paymentMethod
            .dropFirst()
            .sink { [weak self] _ in
                self?.hasUnsavedChanges = true
            }
            .store(in: &cancellables)
        
        $receiptNumber
            .dropFirst()
            .sink { [weak self] _ in
                self?.hasUnsavedChanges = true
            }
            .store(in: &cancellables)
        
        $items
            .dropFirst()
            .sink { [weak self] _ in
                self?.hasUnsavedChanges = true
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Validation Methods
    func validateMerchantName(_ name: String) -> String? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedName.isEmpty {
            return "Merchant name is required"
        }
        
        if trimmedName.count < 2 {
            return "Merchant name must be at least 2 characters"
        }
        
        if trimmedName.count > 100 {
            return "Merchant name cannot exceed 100 characters"
        }
        
        // Check for invalid characters
        let invalidCharacters = CharacterSet.alphanumerics.union(.whitespaces).union(.punctuationCharacters).inverted
        if trimmedName.rangeOfCharacter(from: invalidCharacters) != nil {
            return "Merchant name contains invalid characters"
        }
        
        return nil
    }
    
    func validateTotalAmount(_ amountText: String) -> String? {
        let trimmedAmount = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedAmount.isEmpty {
            return "Total amount is required"
        }
        
        // Check for valid decimal format
        let decimalRegex = "^\\d+(\\.\\d{1,2})?$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", decimalRegex)
        if !predicate.evaluate(with: trimmedAmount) {
            return "Enter a valid amount (e.g., 12.34)"
        }
        
        guard let amount = Decimal(string: trimmedAmount) else {
            return "Invalid amount format"
        }
        
        if amount <= 0 {
            return "Amount must be greater than zero"
        }
        
        if amount > 999999.99 {
            return "Amount cannot exceed $999,999.99"
        }
        
        return nil
    }
    
    func validateTaxAmount(_ amountText: String) -> String? {
        let trimmedAmount = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedAmount.isEmpty {
            return nil // Tax amount is optional
        }
        
        // Check for valid decimal format
        let decimalRegex = "^\\d+(\\.\\d{1,2})?$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", decimalRegex)
        if !predicate.evaluate(with: trimmedAmount) {
            return "Enter a valid tax amount (e.g., 1.25)"
        }
        
        guard let taxAmount = Decimal(string: trimmedAmount) else {
            return "Invalid tax amount format"
        }
        
        if taxAmount < 0 {
            return "Tax amount cannot be negative"
        }
        
        // Validate that tax amount is not greater than total amount
        if let totalAmount = Decimal(string: totalAmountText), taxAmount > totalAmount {
            return "Tax amount cannot exceed total amount"
        }
        
        // Reasonable tax validation (tax shouldn't be more than 50% of total)
        if let totalAmount = Decimal(string: totalAmountText), taxAmount > (totalAmount * 0.5) {
            return "Tax amount seems unusually high"
        }
        
        return nil
    }
    
    func validateReceiptNumber(_ number: String) -> String? {
        let trimmedNumber = number.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedNumber.isEmpty {
            return nil // Receipt number is optional
        }
        
        if trimmedNumber.count > 50 {
            return "Receipt number cannot exceed 50 characters"
        }
        
        return nil
    }
    
    func validateAllFields() -> [String: String] {
        var errors: [String: String] = [:]
        
        if let error = validateMerchantName(merchantName) {
            errors["merchantName"] = error
        }
        
        if let error = validateTotalAmount(totalAmountText) {
            errors["totalAmount"] = error
        }
        
        if let error = validateTaxAmount(taxAmountText) {
            errors["taxAmount"] = error
        }
        
        if let error = validateReceiptNumber(receiptNumber) {
            errors["receiptNumber"] = error
        }
        
        // Validate items
        for (index, item) in items.enumerated() {
            if let error = validateReceiptItem(item) {
                errors["item_\(index)"] = error
            }
        }
        
        return errors
    }
    
    func validateReceiptItem(_ item: ReceiptItemEditModel) -> String? {
        if item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Item name is required"
        }
        
        if item.name.count > 100 {
            return "Item name cannot exceed 100 characters"
        }
        
        if let quantity = item.quantity, quantity <= 0 {
            return "Quantity must be greater than zero"
        }
        
        if let price = item.price, price <= 0 {
            return "Price must be greater than zero"
        }
        
        return nil
    }
    
    // MARK: - Item Management
    func addNewItem() {
        items.append(ReceiptItemEditModel())
    }
    
    func removeItem(at index: Int) {
        guard index < items.count else { return }
        items.remove(at: index)
    }
    
    // MARK: - Actions
    func saveReceipt() {
        // Validate all fields first
        validationErrors = validateAllFields()
        
        guard validationErrors.isEmpty else {
            let errorCount = validationErrors.count
            let errorMessage = errorCount == 1 ? 
                "Please fix the validation error before saving" : 
                "Please fix \(errorCount) validation errors before saving"
            showValidationError(message: errorMessage)
            return
        }
        
        // Show confirmation if there are low-confidence fields
        let lowConfidenceFields = fieldConfidenceScores.filter { $0.value < 0.6 }
        if !lowConfidenceFields.isEmpty && !showConfirmation {
            showConfirmation = true
            return
        }
        
        performSave()
    }
    
    func confirmSave() {
        showConfirmation = false
        performSave()
    }
    
    func cancelSave() {
        showConfirmation = false
    }
    
    private func performSave() {
        Task {
            isSaving = true
            
            do {
                try await saveReceiptToDatabase()
                hasUnsavedChanges = false
                showSaveSuccess = true
            } catch {
                showValidationError(message: "Failed to save receipt: \(error.localizedDescription)")
            }
            
            isSaving = false
        }
    }
    
    func rescanReceipt() {
        // This will be handled by the parent view
        // The parent should dismiss this view and return to camera
    }
    
    // MARK: - Private Methods
    private func saveReceiptToDatabase() async throws {
        let context = coreDataManager.createBackgroundContext()
        
        try await context.perform {
            // Create Receipt entity
            let receipt = Receipt(context: context)
            receipt.id = UUID()
            receipt.merchantName = self.merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
            receipt.date = self.date
            receipt.totalAmount = NSDecimalNumber(decimal: Decimal(string: self.totalAmountText) ?? Decimal.zero)
            receipt.confidence = self.originalReceiptData.confidence
            receipt.dateProcessed = Date()
            receipt.rawTextContent = "" // This would come from OCR if available
            
            // Set optional fields
            if let taxAmount = Decimal(string: self.taxAmountText), !self.taxAmountText.isEmpty {
                receipt.taxAmount = NSDecimalNumber(decimal: taxAmount)
            }
            
            if let paymentMethod = self.paymentMethod, !paymentMethod.isEmpty {
                receipt.paymentMethod = paymentMethod
            }
            
            if !self.receiptNumber.isEmpty {
                receipt.receiptNumber = self.receiptNumber
            }
            
            // Save receipt image
            if let imageData = self.originalImage.jpegData(compressionQuality: 0.8) {
                let imagePath = try self.saveImageToDocuments(imageData: imageData, receiptId: receipt.id)
                receipt.imageURL = URL(fileURLWithPath: imagePath)
            }
            
            // Create ReceiptItem entities
            for itemModel in self.items {
                if !itemModel.name.isEmpty, let price = itemModel.price {
                    let receiptItem = ReceiptItem(context: context)
                    receiptItem.id = UUID()
                    receiptItem.name = itemModel.name
                    receiptItem.totalPrice = NSDecimalNumber(decimal: price)
                    receiptItem.quantity = Int32(itemModel.quantity ?? 1)
                    
                    if let quantity = itemModel.quantity, quantity > 0 {
                        receiptItem.unitPrice = NSDecimalNumber(decimal: price / Decimal(quantity))
                    }
                    
                    receiptItem.receipt = receipt
                }
            }
            
            // Create corresponding Expense entity
            let expense = Expense(context: context)
            expense.id = UUID()
            expense.amount = receipt.totalAmount
            expense.date = receipt.date
            expense.merchant = receipt.merchantName
            expense.notes = "Created from receipt scan"
            expense.receipt = receipt
            expense.paymentMethod = receipt.paymentMethod
            
            // Set default category (this could be enhanced with ML categorization)
            expense.category = self.getDefaultCategory(for: self.merchantName, in: context)
            
            try context.save()
        }
    }
    
    private func saveImageToDocuments(imageData: Data, receiptId: UUID) throws -> String {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let receiptsPath = documentsPath.appendingPathComponent("receipts")
        
        // Create receipts directory if it doesn't exist
        try FileManager.default.createDirectory(at: receiptsPath, withIntermediateDirectories: true)
        
        let fileName = "\(receiptId.uuidString).jpg"
        let fileURL = receiptsPath.appendingPathComponent(fileName)
        
        try imageData.write(to: fileURL)
        
        return fileURL.path
    }
    
    private func getDefaultCategory(for merchantName: String, in context: NSManagedObjectContext) -> Category? {
        // Try to find existing category or create a default one
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", "General")
        request.fetchLimit = 1
        
        if let existingCategory = try? context.fetch(request).first {
            return existingCategory
        }
        
        // Create default category
        let defaultCategory = Category(context: context)
        defaultCategory.id = UUID()
        defaultCategory.name = "General"
        defaultCategory.colorHex = "#007AFF" // Blue
        defaultCategory.icon = "tag"
        defaultCategory.isDefault = true
        
        return defaultCategory
    }
    
    private func showValidationError(message: String) {
        validationErrorMessage = message
        showValidationError = true
    }
}

// MARK: - Extensions

extension Decimal {
    var description: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: self as NSDecimalNumber) ?? "0.00"
    }
}