import Foundation
import CoreData
import UIKit

/// Repository for managing receipt data operations
class ReceiptRepository: ObservableObject {
    static let shared = ReceiptRepository()
    
    private let coreDataManager = CoreDataManager.shared
    private let imageManager = ImageManager.shared
    
    private init() {}
    
    // MARK: - CRUD Operations
    
    /// Creates a new receipt with image data
    /// - Parameters:
    ///   - receiptData: The receipt data extracted from OCR
    ///   - originalImage: The original receipt image
    ///   - processedImage: The processed receipt image (optional)
    ///   - rawText: The raw OCR text (optional)
    /// - Returns: The created receipt
    @MainActor
    func createReceipt(
        receiptData: ReceiptData,
        originalImage: UIImage,
        processedImage: UIImage? = nil,
        rawText: String? = nil
    ) async throws -> Receipt {
        let context = coreDataManager.viewContext
        
        // Save images first
        let imageURLs = try await imageManager.processAndSaveReceiptImage(originalImage)
        
        // Create the receipt entity
        let receipt = Receipt(context: context)
        receipt.id = UUID()
        receipt.imageURL = imageURLs.originalURL
        receipt.processedImageURL = imageURLs.processedURL
        receipt.dateProcessed = Date()
        receipt.rawTextContent = rawText
        receipt.merchantName = receiptData.merchantName
        receipt.date = receiptData.date
        receipt.totalAmount = NSDecimalNumber(decimal: receiptData.totalAmount)
        receipt.taxAmount = receiptData.taxAmount.map { NSDecimalNumber(decimal: $0) }
        receipt.paymentMethod = receiptData.paymentMethod
        receipt.receiptNumber = receiptData.receiptNumber
        receipt.confidence = receiptData.confidence
        
        // Create receipt items if available
        if let items = receiptData.items {
            for itemData in items {
                let receiptItem = ReceiptItem(context: context)
                receiptItem.id = UUID()
                receiptItem.name = itemData.name
                receiptItem.quantity = Int32(itemData.quantity ?? 1)
                receiptItem.unitPrice = itemData.unitPrice.map { NSDecimalNumber(decimal: $0) }
                receiptItem.totalPrice = NSDecimalNumber(decimal: itemData.totalPrice)
                receiptItem.receipt = receipt
            }
        }
        
        // Save the context
        coreDataManager.save()
        
        return receipt
    }
    
    /// Retrieves a receipt by ID
    /// - Parameter id: The receipt ID
    /// - Returns: The receipt if found, nil otherwise
    func getReceipt(by id: UUID) -> Receipt? {
        let context = coreDataManager.viewContext
        let request: NSFetchRequest<Receipt> = Receipt.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        do {
            let receipts = try context.fetch(request)
            return receipts.first
        } catch {
            print("Error fetching receipt by ID: \(error)")
            return nil
        }
    }
    
    /// Retrieves all receipts with optional filtering
    /// - Parameter filter: Optional filter criteria
    /// - Returns: Array of receipts matching the filter
    func getReceipts(filter: ReceiptFilter? = nil) -> [Receipt] {
        let context = coreDataManager.viewContext
        let request: NSFetchRequest<Receipt> = Receipt.fetchRequest()
        
        // Apply filters
        var predicates: [NSPredicate] = []
        
        if let filter = filter {
            if let startDate = filter.startDate {
                predicates.append(NSPredicate(format: "date >= %@", startDate as NSDate))
            }
            
            if let endDate = filter.endDate {
                predicates.append(NSPredicate(format: "date <= %@", endDate as NSDate))
            }
            
            if let merchantName = filter.merchantName, !merchantName.isEmpty {
                predicates.append(NSPredicate(format: "merchantName CONTAINS[cd] %@", merchantName))
            }
            
            if let minAmount = filter.minAmount {
                predicates.append(NSPredicate(format: "totalAmount >= %@", NSDecimalNumber(decimal: minAmount)))
            }
            
            if let maxAmount = filter.maxAmount {
                predicates.append(NSPredicate(format: "totalAmount <= %@", NSDecimalNumber(decimal: maxAmount)))
            }
            
            if let minConfidence = filter.minConfidence {
                predicates.append(NSPredicate(format: "confidence >= %f", minConfidence))
            }
        }
        
        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        
        // Apply sorting
        request.sortDescriptors = [
            NSSortDescriptor(key: "date", ascending: false),
            NSSortDescriptor(key: "dateProcessed", ascending: false)
        ]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching receipts: \(error)")
            return []
        }
    }
    
    /// Updates an existing receipt
    /// - Parameter receipt: The receipt to update
    /// - Returns: The updated receipt
    func updateReceipt(_ receipt: Receipt) throws -> Receipt {
        let context = coreDataManager.viewContext
        
        // Ensure the receipt is in the current context
        guard context.object(with: receipt.objectID) is Receipt else {
            throw ReceiptRepositoryError.receiptNotFound
        }
        
        coreDataManager.save()
        return receipt
    }
    
    /// Updates receipt data with new extracted information
    /// - Parameters:
    ///   - receipt: The receipt to update
    ///   - receiptData: The new receipt data
    ///   - rawText: The raw OCR text (optional)
    /// - Returns: The updated receipt
    func updateReceiptData(_ receipt: Receipt, with receiptData: ReceiptData, rawText: String? = nil) throws -> Receipt {
        let context = coreDataManager.viewContext
        
        // Ensure the receipt is in the current context
        guard context.object(with: receipt.objectID) is Receipt else {
            throw ReceiptRepositoryError.receiptNotFound
        }
        
        // Update receipt properties
        receipt.rawTextContent = rawText
        receipt.merchantName = receiptData.merchantName
        receipt.date = receiptData.date
        receipt.totalAmount = NSDecimalNumber(decimal: receiptData.totalAmount)
        receipt.taxAmount = receiptData.taxAmount.map { NSDecimalNumber(decimal: $0) }
        receipt.paymentMethod = receiptData.paymentMethod
        receipt.receiptNumber = receiptData.receiptNumber
        receipt.confidence = receiptData.confidence
        
        // Remove existing items
        if let existingItems = receipt.items {
            for item in existingItems {
                context.delete(item as! ReceiptItem)
            }
        }
        
        // Create new receipt items if available
        if let items = receiptData.items {
            for itemData in items {
                let receiptItem = ReceiptItem(context: context)
                receiptItem.id = UUID()
                receiptItem.name = itemData.name
                receiptItem.quantity = Int32(itemData.quantity ?? 1)
                receiptItem.unitPrice = itemData.unitPrice.map { NSDecimalNumber(decimal: $0) }
                receiptItem.totalPrice = NSDecimalNumber(decimal: itemData.totalPrice)
                receiptItem.receipt = receipt
            }
        }
        
        coreDataManager.save()
        return receipt
    }
    
    /// Deletes a receipt and its associated images
    /// - Parameter receipt: The receipt to delete
    func deleteReceipt(_ receipt: Receipt) throws {
        let context = coreDataManager.viewContext
        
        // Ensure the receipt is in the current context
        guard let receiptToDelete = try? context.existingObject(with: receipt.objectID) as? Receipt else {
            throw ReceiptRepositoryError.receiptNotFound
        }
        
        // Delete associated images
        _ = imageManager.deleteReceiptImage(at: receiptToDelete.imageURL)
        if let processedImageURL = receiptToDelete.processedImageURL {
            _ = imageManager.deleteReceiptImage(at: processedImageURL)
        }
        
        // Delete the receipt entity
        context.delete(receiptToDelete)
        coreDataManager.save()
    }
    
    /// Deletes multiple receipts
    /// - Parameter receipts: The receipts to delete
    func deleteReceipts(_ receipts: [Receipt]) throws {
        let context = coreDataManager.viewContext
        
        for receipt in receipts {
            guard let receiptToDelete = try? context.existingObject(with: receipt.objectID) as? Receipt else {
                continue
            }
            
            // Delete associated images
            _ = imageManager.deleteReceiptImage(at: receiptToDelete.imageURL)
            if let processedImageURL = receiptToDelete.processedImageURL {
                _ = imageManager.deleteReceiptImage(at: processedImageURL)
            }
            
            // Delete the receipt entity
            context.delete(receiptToDelete)
        }
        
        coreDataManager.save()
    }
    
    // MARK: - Image Operations
    
    /// Retrieves the original image for a receipt
    /// - Parameter receipt: The receipt
    /// - Returns: The original image if available
    func getOriginalImage(for receipt: Receipt) -> UIImage? {
        return imageManager.loadReceiptImage(from: receipt.imageURL)
    }
    
    /// Retrieves the processed image for a receipt
    /// - Parameter receipt: The receipt
    /// - Returns: The processed image if available
    func getProcessedImage(for receipt: Receipt) -> UIImage? {
        guard let processedImageURL = receipt.processedImageURL else {
            return nil
        }
        return imageManager.loadReceiptImage(from: processedImageURL)
    }
    
    /// Updates the processed image for a receipt
    /// - Parameters:
    ///   - receipt: The receipt to update
    ///   - processedImage: The new processed image
    /// - Returns: The updated receipt
    @MainActor
    func updateProcessedImage(for receipt: Receipt, with processedImage: UIImage) async throws -> Receipt {
        let context = coreDataManager.viewContext
        
        // Ensure the receipt is in the current context
        guard context.object(with: receipt.objectID) is Receipt else {
            throw ReceiptRepositoryError.receiptNotFound
        }
        
        // Delete old processed image if it exists
        if let oldProcessedImageURL = receipt.processedImageURL {
            _ = imageManager.deleteReceiptImage(at: oldProcessedImageURL)
        }
        
        // Save new processed image
        let newProcessedImageURL = imageManager.saveProcessedReceiptImage(processedImage, originalImageURL: receipt.imageURL)
        receipt.processedImageURL = newProcessedImageURL
        
        coreDataManager.save()
        return receipt
    }
    
    // MARK: - Statistics and Analytics
    
    /// Gets receipt count for a date range
    /// - Parameters:
    ///   - startDate: Start date (optional)
    ///   - endDate: End date (optional)
    /// - Returns: Number of receipts in the date range
    func getReceiptCount(from startDate: Date? = nil, to endDate: Date? = nil) -> Int {
        let context = coreDataManager.viewContext
        let request: NSFetchRequest<Receipt> = Receipt.fetchRequest()
        
        var predicates: [NSPredicate] = []
        
        if let startDate = startDate {
            predicates.append(NSPredicate(format: "date >= %@", startDate as NSDate))
        }
        
        if let endDate = endDate {
            predicates.append(NSPredicate(format: "date <= %@", endDate as NSDate))
        }
        
        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        
        do {
            return try context.count(for: request)
        } catch {
            print("Error counting receipts: \(error)")
            return 0
        }
    }
    
    /// Gets total amount for receipts in a date range
    /// - Parameters:
    ///   - startDate: Start date (optional)
    ///   - endDate: End date (optional)
    /// - Returns: Total amount of receipts in the date range
    func getTotalAmount(from startDate: Date? = nil, to endDate: Date? = nil) -> Decimal {
        let receipts = getReceipts(filter: ReceiptFilter(startDate: startDate, endDate: endDate))
        return receipts.reduce(Decimal.zero) { total, receipt in
            total + receipt.totalAmount.decimalValue
        }
    }
    
    /// Gets receipts grouped by merchant
    /// - Parameter limit: Maximum number of merchants to return
    /// - Returns: Dictionary of merchant names to receipt arrays
    func getReceiptsByMerchant(limit: Int = 10) -> [String: [Receipt]] {
        let receipts = getReceipts()
        let groupedReceipts = Dictionary(grouping: receipts) { $0.merchantName }
        
        // Sort by number of receipts and limit results
        let sortedMerchants = groupedReceipts.keys.sorted { merchant1, merchant2 in
            groupedReceipts[merchant1]!.count > groupedReceipts[merchant2]!.count
        }
        
        var result: [String: [Receipt]] = [:]
        for (index, merchant) in sortedMerchants.enumerated() {
            if index >= limit { break }
            result[merchant] = groupedReceipts[merchant]
        }
        
        return result
    }
    
    // MARK: - Background Operations
    
    /// Performs background cleanup of orphaned images
    func cleanupOrphanedImages() {
        let context = coreDataManager.createBackgroundContext()
        
        context.perform {
            // Get all receipt image URLs from the database
            let request: NSFetchRequest<Receipt> = Receipt.fetchRequest()
            request.propertiesToFetch = ["imageURL", "processedImageURL"]
            
            do {
                let receipts = try context.fetch(request)
                let usedImageURLs = Set(receipts.flatMap { receipt in
                    [receipt.imageURL, receipt.processedImageURL].compactMap { $0 }
                })
                
                // Get all image files in the directory
                let imageDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                    .appendingPathComponent("ReceiptImages", isDirectory: true)
                
                let imageFiles = try FileManager.default.contentsOfDirectory(at: imageDirectory, includingPropertiesForKeys: nil)
                
                // Delete orphaned images
                for imageFile in imageFiles {
                    if !usedImageURLs.contains(imageFile) {
                        try? FileManager.default.removeItem(at: imageFile)
                        print("Deleted orphaned image: \(imageFile.lastPathComponent)")
                    }
                }
            } catch {
                print("Error during image cleanup: \(error)")
            }
        }
    }
}

// MARK: - Supporting Types

/// Filter criteria for receipt queries
struct ReceiptFilter {
    let startDate: Date?
    let endDate: Date?
    let merchantName: String?
    let minAmount: Decimal?
    let maxAmount: Decimal?
    let minConfidence: Float?
    
    init(
        startDate: Date? = nil,
        endDate: Date? = nil,
        merchantName: String? = nil,
        minAmount: Decimal? = nil,
        maxAmount: Decimal? = nil,
        minConfidence: Float? = nil
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.merchantName = merchantName
        self.minAmount = minAmount
        self.maxAmount = maxAmount
        self.minConfidence = minConfidence
    }
}



/// Repository-specific errors
enum ReceiptRepositoryError: Error, LocalizedError {
    case receiptNotFound
    case imageProcessingFailed(String)
    case storageError(String)
    
    var errorDescription: String? {
        switch self {
        case .receiptNotFound:
            return "Receipt not found"
        case .imageProcessingFailed(let message):
            return "Image processing failed: \(message)"
        case .storageError(let message):
            return "Storage error: \(message)"
        }
    }
}