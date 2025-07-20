import Foundation
import Vision
import UIKit
import CoreData

// MARK: - Data Transfer Objects
struct ReceiptData {
    let merchantName: String
    let date: Date
    let totalAmount: Decimal
    let taxAmount: Decimal?
    let items: [ReceiptItemData]?
    let paymentMethod: String?
    let receiptNumber: String?
    let confidence: Float
}

struct ReceiptItemData {
    let name: String
    let quantity: Int?
    let unitPrice: Decimal?
    let totalPrice: Decimal
}

// MARK: - OCR Service Protocol
protocol OCRServiceProtocol {
    func extractTextFromImage(_ image: UIImage) async throws -> String
    func parseReceiptData(_ text: String) async throws -> ReceiptData
}

// MARK: - OCR Service Implementation
class OCRService: OCRServiceProtocol {
    
    // MARK: - Error Types
    enum OCRError: Error, LocalizedError {
        case imageProcessingFailed
        case textRecognitionFailed
        case noTextFound
        case parsingFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .imageProcessingFailed:
                return "Failed to process the image for text recognition"
            case .textRecognitionFailed:
                return "Text recognition failed"
            case .noTextFound:
                return "No text was found in the image"
            case .parsingFailed(let reason):
                return "Failed to parse receipt data: \(reason)"
            }
        }
    }
    
    // MARK: - Text Extraction
    func extractTextFromImage(_ image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw OCRError.imageProcessingFailed
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: OCRError.textRecognitionFailed)
                    return
                }
                
                let recognizedStrings = observations.compactMap { observation in
                    return try? observation.topCandidates(1).first?.string
                }
                
                if recognizedStrings.isEmpty {
                    continuation.resume(throwing: OCRError.noTextFound)
                } else {
                    let fullText = recognizedStrings.joined(separator: "\n")
                    continuation.resume(returning: fullText)
                }
            }
            
            // Configure the request for better accuracy
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    // MARK: - Receipt Data Parsing
    func parseReceiptData(_ text: String) async throws -> ReceiptData {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        var merchantName = ""
        var date = Date()
        var totalAmount = Decimal.zero
        var taxAmount: Decimal?
        var items: [ReceiptItemData] = []
        var paymentMethod: String?
        var receiptNumber: String?
        var overallConfidence: Float = 0.0
        
        // Parse merchant name (usually first few lines)
        merchantName = extractMerchantName(from: lines)
        
        // Parse date
        if let extractedDate = extractDate(from: lines) {
            date = extractedDate
        }
        
        // Parse total amount
        if let extractedTotal = extractTotalAmount(from: lines) {
            totalAmount = extractedTotal
        }
        
        // Parse tax amount
        taxAmount = extractTaxAmount(from: lines)
        
        // Parse items
        items = extractItems(from: lines)
        
        // Parse payment method
        paymentMethod = extractPaymentMethod(from: lines)
        
        // Parse receipt number
        receiptNumber = extractReceiptNumber(from: lines)
        
        // Calculate overall confidence based on successfully extracted fields
        overallConfidence = calculateConfidence(
            merchantName: merchantName,
            totalAmount: totalAmount,
            taxAmount: taxAmount,
            items: items,
            paymentMethod: paymentMethod,
            receiptNumber: receiptNumber
        )
        
        return ReceiptData(
            merchantName: merchantName,
            date: date,
            totalAmount: totalAmount,
            taxAmount: taxAmount,
            items: items.isEmpty ? nil : items,
            paymentMethod: paymentMethod,
            receiptNumber: receiptNumber,
            confidence: overallConfidence
        )
    }
}

// MARK: - Private Parsing Methods
private extension OCRService {
    
    func extractMerchantName(from lines: [String]) -> String {
        // Look for merchant name in the first few lines
        // Skip common receipt headers and look for business names
        let skipPatterns = [
            "receipt", "invoice", "bill", "order", "transaction",
            "customer copy", "merchant copy", "thank you"
        ]
        
        for (index, line) in lines.enumerated() {
            if index > 5 { break } // Only check first 6 lines
            
            let lowercaseLine = line.lowercased()
            let shouldSkip = skipPatterns.contains { pattern in
                lowercaseLine.contains(pattern)
            }
            
            if !shouldSkip && line.count > 2 && !line.allSatisfy({ $0.isNumber || $0.isPunctuation }) {
                return line
            }
        }
        
        return lines.first ?? "Unknown Merchant"
    }
    
    func extractDate(from lines: [String]) -> Date? {
        let dateFormatter = DateFormatter()
        let datePatterns = [
            "MM/dd/yyyy", "MM-dd-yyyy", "yyyy-MM-dd",
            "dd/MM/yyyy", "dd-MM-yyyy", "MMM dd, yyyy",
            "dd MMM yyyy", "MMMM dd, yyyy"
        ]
        
        for line in lines {
            for pattern in datePatterns {
                dateFormatter.dateFormat = pattern
                if let date = dateFormatter.date(from: line) {
                    return date
                }
                
                // Try to extract date from longer strings
                let words = line.components(separatedBy: .whitespaces)
                for word in words {
                    if let date = dateFormatter.date(from: word) {
                        return date
                    }
                }
            }
        }
        
        // Try regex patterns for common date formats
        let dateRegexPatterns = [
            #"\d{1,2}/\d{1,2}/\d{4}"#,
            #"\d{1,2}-\d{1,2}-\d{4}"#,
            #"\d{4}-\d{1,2}-\d{1,2}"#
        ]
        
        for line in lines {
            for pattern in dateRegexPatterns {
                if let range = line.range(of: pattern, options: .regularExpression) {
                    let dateString = String(line[range])
                    for formatPattern in datePatterns {
                        dateFormatter.dateFormat = formatPattern
                        if let date = dateFormatter.date(from: dateString) {
                            return date
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    func extractTotalAmount(from lines: [String]) -> Decimal? {
        let totalKeywords = ["total", "amount due", "balance", "grand total", "subtotal"]
        
        for line in lines.reversed() { // Start from bottom as total is usually at the end
            let lowercaseLine = line.lowercased()
            
            for keyword in totalKeywords {
                if lowercaseLine.contains(keyword) {
                    if let amount = extractAmountFromLine(line) {
                        return amount
                    }
                }
            }
        }
        
        // If no keyword found, look for the largest amount in the receipt
        var amounts: [Decimal] = []
        for line in lines {
            if let amount = extractAmountFromLine(line) {
                amounts.append(amount)
            }
        }
        
        return amounts.max()
    }
    
    func extractTaxAmount(from lines: [String]) -> Decimal? {
        let taxKeywords = ["tax", "vat", "gst", "hst", "sales tax"]
        
        for line in lines {
            let lowercaseLine = line.lowercased()
            
            for keyword in taxKeywords {
                if lowercaseLine.contains(keyword) {
                    return extractAmountFromLine(line)
                }
            }
        }
        
        return nil
    }
    
    func extractAmountFromLine(_ line: String) -> Decimal? {
        // Regex pattern to match currency amounts
        let pattern = #"\$?(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)"#
        
        if let range = line.range(of: pattern, options: .regularExpression) {
            let amountString = String(line[range])
                .replacingOccurrences(of: "$", with: "")
                .replacingOccurrences(of: ",", with: "")
            
            return Decimal(string: amountString)
        }
        
        return nil
    }
    
    func extractItems(from lines: [String]) -> [ReceiptItemData] {
        var items: [ReceiptItemData] = []
        
        // Look for lines that contain both text and amounts
        for line in lines {
            // Skip lines that are likely headers or totals
            let lowercaseLine = line.lowercased()
            if lowercaseLine.contains("total") || 
               lowercaseLine.contains("tax") || 
               lowercaseLine.contains("subtotal") ||
               lowercaseLine.contains("change") ||
               lowercaseLine.contains("payment") {
                continue
            }
            
            // Look for lines with item patterns: "Item Name $X.XX" or "Qty Item Name $X.XX"
            if let amount = extractAmountFromLine(line) {
                let itemName = extractItemNameFromLine(line)
                let quantity = extractQuantityFromLine(line)
                
                if !itemName.isEmpty {
                    let item = ReceiptItemData(
                        name: itemName,
                        quantity: quantity,
                        unitPrice: quantity != nil && quantity! > 0 ? amount / Decimal(quantity!) : nil,
                        totalPrice: amount
                    )
                    items.append(item)
                }
            }
        }
        
        return items
    }
    
    func extractItemNameFromLine(_ line: String) -> String {
        // Remove amount and quantity to get item name
        var cleanLine = line
        
        // Remove amounts
        let amountPattern = #"\$?\d{1,3}(?:,\d{3})*(?:\.\d{2})?"#
        cleanLine = cleanLine.replacingOccurrences(of: amountPattern, with: "", options: .regularExpression)
        
        // Remove quantity patterns at the beginning
        let quantityPattern = #"^\d+\s*x?\s*"#
        cleanLine = cleanLine.replacingOccurrences(of: quantityPattern, with: "", options: .regularExpression)
        
        return cleanLine.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func extractQuantityFromLine(_ line: String) -> Int? {
        // Look for quantity patterns at the beginning of the line
        let quantityPattern = #"^(\d+)\s*x?\s*"#
        
        if let range = line.range(of: quantityPattern, options: .regularExpression) {
            let quantityString = String(line[range])
                .replacingOccurrences(of: "x", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            return Int(quantityString)
        }
        
        return nil
    }
    
    func extractPaymentMethod(from lines: [String]) -> String? {
        let paymentKeywords = [
            ("visa", "Visa"),
            ("mastercard", "Mastercard"),
            ("amex", "Amex"),
            ("american express", "American Express"),
            ("discover", "Discover"),
            ("cash", "Cash"),
            ("credit", "Credit"),
            ("debit", "Debit"),
            ("card", "Card"),
            ("chip", "Chip"),
            ("contactless", "Contactless")
        ]
        
        for line in lines {
            let lowercaseLine = line.lowercased()
            
            for (keyword, displayName) in paymentKeywords {
                if lowercaseLine.contains(keyword) {
                    return displayName
                }
            }
        }
        
        return nil
    }
    
    func extractReceiptNumber(from lines: [String]) -> String? {
        let receiptKeywords = ["receipt", "transaction", "ref", "order"]
        
        for line in lines {
            let lowercaseLine = line.lowercased()
            
            for keyword in receiptKeywords {
                if lowercaseLine.contains(keyword) {
                    // Look for numbers in the same line
                    let numberPattern = #"\d{4,}"# // At least 4 digits
                    if let range = line.range(of: numberPattern, options: .regularExpression) {
                        return String(line[range])
                    }
                }
            }
        }
        
        return nil
    }
    
    func calculateConfidence(
        merchantName: String,
        totalAmount: Decimal,
        taxAmount: Decimal?,
        items: [ReceiptItemData],
        paymentMethod: String?,
        receiptNumber: String?
    ) -> Float {
        var score: Float = 0.0
        var maxScore: Float = 6.0
        
        // Merchant name confidence
        if !merchantName.isEmpty && merchantName != "Unknown Merchant" {
            score += 1.0
        }
        
        // Total amount confidence
        if totalAmount > 0 {
            score += 1.5 // Higher weight for total amount
        }
        
        // Tax amount confidence
        if taxAmount != nil {
            score += 0.5
        }
        
        // Items confidence
        if !items.isEmpty {
            score += 1.0
        }
        
        // Payment method confidence
        if paymentMethod != nil {
            score += 0.5
        }
        
        // Receipt number confidence
        if receiptNumber != nil {
            score += 0.5
        }
        
        return min(score / maxScore, 1.0)
    }
}