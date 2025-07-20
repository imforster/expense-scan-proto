import Foundation
import Vision
import UIKit
import CoreData
import CoreML
import NaturalLanguage

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

// MARK: - Field Classification Types
enum ReceiptFieldType {
    case merchantName
    case date
    case totalAmount
    case taxAmount
    case subtotalAmount
    case item
    case paymentMethod
    case receiptNumber
    case unknown
}

struct ClassifiedLine {
    let text: String
    let fieldType: ReceiptFieldType
    let confidence: Float
    let extractedValue: Any?
}

// MARK: - OCR Service Implementation
class OCRService: OCRServiceProtocol {
    
    // MARK: - Properties
    private let languageRecognizer = NLLanguageRecognizer()
    private let merchantPatterns = ReceiptMerchantPatterns()
    private let fieldClassifier = ReceiptFieldClassifier()
    
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
        
        // Use machine learning-based field classification
        let classifiedLines = await classifyReceiptLines(lines)
        
        // Extract data using both traditional parsing and ML classification
        let extractedData = await extractDataFromClassifiedLines(classifiedLines, originalLines: lines)
        
        return extractedData
    }
    
    // MARK: - Advanced ML-Based Parsing
    private func classifyReceiptLines(_ lines: [String]) async -> [ClassifiedLine] {
        var classifiedLines: [ClassifiedLine] = []
        
        for (index, line) in lines.enumerated() {
            let fieldType = fieldClassifier.classifyLine(line, position: index, totalLines: lines.count)
            let confidence = fieldClassifier.getConfidenceForClassification(line, fieldType: fieldType)
            
            var extractedValue: Any?
            switch fieldType {
            case .merchantName:
                extractedValue = merchantPatterns.extractMerchantName(from: line)
            case .date:
                extractedValue = extractDateFromLine(line)
            case .totalAmount, .taxAmount, .subtotalAmount:
                extractedValue = extractAmountFromLine(line)
            case .paymentMethod:
                extractedValue = extractPaymentMethodFromLine(line)
            case .receiptNumber:
                extractedValue = extractReceiptNumberFromLine(line)
            case .item:
                extractedValue = parseItemFromLine(line)
            case .unknown:
                break
            }
            
            classifiedLines.append(ClassifiedLine(
                text: line,
                fieldType: fieldType,
                confidence: confidence,
                extractedValue: extractedValue
            ))
        }
        
        return classifiedLines
    }
    
    private func extractDataFromClassifiedLines(_ classifiedLines: [ClassifiedLine], originalLines: [String]) async -> ReceiptData {
        var merchantName = "Unknown Merchant"
        var date = Date()
        var totalAmount = Decimal.zero
        var taxAmount: Decimal?
        var items: [ReceiptItemData] = []
        var paymentMethod: String?
        var receiptNumber: String?
        
        // Process classified lines with confidence thresholds
        for classifiedLine in classifiedLines {
            guard classifiedLine.confidence > 0.3 else { continue } // Skip low-confidence classifications
            
            switch classifiedLine.fieldType {
            case .merchantName:
                if let extractedMerchant = classifiedLine.extractedValue as? String,
                   !extractedMerchant.isEmpty,
                   classifiedLine.confidence > 0.5 {
                    merchantName = extractedMerchant
                }
                
            case .date:
                if let extractedDate = classifiedLine.extractedValue as? Date {
                    date = extractedDate
                }
                
            case .totalAmount:
                if let amount = classifiedLine.extractedValue as? Decimal,
                   amount > totalAmount { // Take the highest amount classified as total
                    totalAmount = amount
                }
                
            case .taxAmount:
                if let amount = classifiedLine.extractedValue as? Decimal {
                    taxAmount = amount
                }
                
            case .item:
                if let item = classifiedLine.extractedValue as? ReceiptItemData {
                    items.append(item)
                }
                
            case .paymentMethod:
                if let method = classifiedLine.extractedValue as? String {
                    paymentMethod = method
                }
                
            case .receiptNumber:
                if let number = classifiedLine.extractedValue as? String {
                    receiptNumber = number
                }
                
            case .subtotalAmount, .unknown:
                break
            }
        }
        
        // Fallback to traditional parsing if ML classification didn't find key fields
        if merchantName == "Unknown Merchant" {
            merchantName = extractMerchantName(from: originalLines)
        }
        
        if totalAmount == Decimal.zero {
            totalAmount = extractTotalAmount(from: originalLines) ?? Decimal.zero
        }
        
        if taxAmount == nil {
            taxAmount = extractTaxAmount(from: originalLines)
        }
        
        if items.isEmpty {
            items = extractItems(from: originalLines)
        }
        
        if paymentMethod == nil {
            paymentMethod = extractPaymentMethod(from: originalLines)
        }
        
        if receiptNumber == nil {
            receiptNumber = extractReceiptNumber(from: originalLines)
        }
        
        // Calculate overall confidence
        let overallConfidence = calculateAdvancedConfidence(
            classifiedLines: classifiedLines,
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
    
    // MARK: - Advanced Parsing Helper Methods
    
    func extractDateFromLine(_ line: String) -> Date? {
        let dateFormatter = DateFormatter()
        let datePatterns = [
            "MM/dd/yyyy", "MM-dd-yyyy", "yyyy-MM-dd",
            "dd/MM/yyyy", "dd-MM-yyyy", "MMM dd, yyyy",
            "dd MMM yyyy", "MMMM dd, yyyy", "MM/dd/yy"
        ]
        
        // Try direct parsing first
        for pattern in datePatterns {
            dateFormatter.dateFormat = pattern
            if let date = dateFormatter.date(from: line.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return date
            }
        }
        
        // Try regex extraction
        let dateRegexPatterns = [
            #"\d{1,2}/\d{1,2}/\d{4}"#,
            #"\d{1,2}-\d{1,2}-\d{4}"#,
            #"\d{4}-\d{1,2}-\d{1,2}"#,
            #"\d{1,2}/\d{1,2}/\d{2}"#
        ]
        
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
        
        return nil
    }
    
    func extractPaymentMethodFromLine(_ line: String) -> String? {
        let paymentKeywords = [
            ("visa", "Visa"),
            ("mastercard", "Mastercard"),
            ("amex", "Amex"),
            ("american express", "American Express"),
            ("discover", "Discover"),
            ("cash", "Cash"),
            ("credit", "Credit"),
            ("debit", "Debit"),
            ("chip", "Chip"),
            ("contactless", "Contactless")
        ]
        
        let lowercaseLine = line.lowercased()
        
        for (keyword, displayName) in paymentKeywords {
            if lowercaseLine.contains(keyword) {
                return displayName
            }
        }
        
        return nil
    }
    
    func extractReceiptNumberFromLine(_ line: String) -> String? {
        let receiptKeywords = ["receipt", "transaction", "ref", "order", "#"]
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
        
        return nil
    }
    
    func parseItemFromLine(_ line: String) -> ReceiptItemData? {
        guard let amount = extractAmountFromLine(line) else { return nil }
        
        let itemName = extractItemNameFromLine(line)
        let quantity = extractQuantityFromLine(line)
        
        guard !itemName.isEmpty else { return nil }
        
        return ReceiptItemData(
            name: itemName,
            quantity: quantity,
            unitPrice: quantity != nil && quantity! > 0 ? amount / Decimal(quantity!) : nil,
            totalPrice: amount
        )
    }
    
    func calculateAdvancedConfidence(
        classifiedLines: [ClassifiedLine],
        merchantName: String,
        totalAmount: Decimal,
        taxAmount: Decimal?,
        items: [ReceiptItemData],
        paymentMethod: String?,
        receiptNumber: String?
    ) -> Float {
        // Base confidence from traditional parsing
        let baseConfidence = calculateConfidence(
            merchantName: merchantName,
            totalAmount: totalAmount,
            taxAmount: taxAmount,
            items: items,
            paymentMethod: paymentMethod,
            receiptNumber: receiptNumber
        )
        
        // ML classification confidence boost
        let mlConfidenceSum = classifiedLines.reduce(0.0) { sum, line in
            return sum + line.confidence
        }
        let avgMLConfidence = classifiedLines.isEmpty ? 0.0 : mlConfidenceSum / Float(classifiedLines.count)
        
        // Weighted combination of base confidence and ML confidence
        let combinedConfidence = (baseConfidence * 0.7) + (avgMLConfidence * 0.3)
        
        return min(combinedConfidence, 1.0)
    }
}

// MARK: - Receipt Field Classifier
class ReceiptFieldClassifier {
    
    private let merchantKeywords = ["store", "shop", "market", "restaurant", "cafe", "inc", "llc", "ltd", "corp"]
    private let totalKeywords = ["total", "amount due", "balance", "grand total"]
    private let taxKeywords = ["tax", "vat", "gst", "hst", "sales tax"]
    private let paymentKeywords = ["visa", "mastercard", "amex", "cash", "credit", "debit", "card"]
    private let receiptKeywords = ["receipt", "transaction", "ref", "order", "#"]
    
    func classifyLine(_ line: String, position: Int, totalLines: Int) -> ReceiptFieldType {
        let lowercaseLine = line.lowercased()
        let normalizedPosition = Float(position) / Float(totalLines)
        
        // Date patterns (high priority)
        if containsDatePattern(line) {
            return .date
        }
        
        // Amount patterns with context
        if let _ = extractAmountFromLine(line) {
            if containsKeywords(lowercaseLine, keywords: totalKeywords) {
                return .totalAmount
            } else if containsKeywords(lowercaseLine, keywords: taxKeywords) {
                return .taxAmount
            } else if normalizedPosition > 0.7 { // Totals are usually at the bottom
                return .totalAmount
            } else if normalizedPosition > 0.3 && normalizedPosition < 0.7 {
                return .item // Items are typically in the middle
            }
        }
        
        // Payment method
        if containsKeywords(lowercaseLine, keywords: paymentKeywords) {
            return .paymentMethod
        }
        
        // Receipt number
        if containsKeywords(lowercaseLine, keywords: receiptKeywords) && containsNumbers(line) {
            return .receiptNumber
        }
        
        // Merchant name is typically in the first 30% of the receipt
        if normalizedPosition < 0.3 && containsBusinessIndicators(lowercaseLine) {
            return .merchantName
        }
        
        // Item detection (has text and amount, in middle section)
        if normalizedPosition > 0.2 && normalizedPosition < 0.8 && 
           extractAmountFromLine(line) != nil && 
           hasItemCharacteristics(line) {
            return .item
        }
        
        return .unknown
    }
    
    func getConfidenceForClassification(_ line: String, fieldType: ReceiptFieldType) -> Float {
        let lowercaseLine = line.lowercased()
        
        switch fieldType {
        case .merchantName:
            return containsBusinessIndicators(lowercaseLine) ? 0.8 : 0.4
            
        case .date:
            return containsDatePattern(line) ? 0.9 : 0.3
            
        case .totalAmount:
            let hasAmount = extractAmountFromLine(line) != nil
            let hasKeyword = containsKeywords(lowercaseLine, keywords: totalKeywords)
            return hasAmount && hasKeyword ? 0.9 : (hasAmount ? 0.6 : 0.3)
            
        case .taxAmount:
            let hasAmount = extractAmountFromLine(line) != nil
            let hasKeyword = containsKeywords(lowercaseLine, keywords: taxKeywords)
            return hasAmount && hasKeyword ? 0.9 : 0.4
            
        case .paymentMethod:
            return containsKeywords(lowercaseLine, keywords: paymentKeywords) ? 0.8 : 0.3
            
        case .receiptNumber:
            let hasKeyword = containsKeywords(lowercaseLine, keywords: receiptKeywords)
            let hasNumbers = containsNumbers(line)
            return hasKeyword && hasNumbers ? 0.8 : 0.4
            
        case .item:
            let hasAmount = extractAmountFromLine(line) != nil
            let hasItemChars = hasItemCharacteristics(line)
            return hasAmount && hasItemChars ? 0.7 : 0.4
            
        case .subtotalAmount:
            return 0.6
            
        case .unknown:
            return 0.1
        }
    }
    
    private func containsBusinessIndicators(_ line: String) -> Bool {
        return merchantKeywords.contains { line.contains($0) } ||
               line.count > 3 && !line.allSatisfy({ $0.isNumber || $0.isPunctuation })
    }
    
    private func containsDatePattern(_ line: String) -> Bool {
        let datePatterns = [
            #"\d{1,2}/\d{1,2}/\d{4}"#,
            #"\d{1,2}-\d{1,2}-\d{4}"#,
            #"\d{4}-\d{1,2}-\d{1,2}"#,
            #"\b\w{3}\s+\d{1,2},?\s+\d{4}\b"#, // Jan 15, 2023
            #"\b\d{1,2}\s+\w{3}\s+\d{4}\b"# // 15 Jan 2023
        ]
        
        return datePatterns.contains { pattern in
            line.range(of: pattern, options: .regularExpression) != nil
        }
    }
    
    private func containsKeywords(_ line: String, keywords: [String]) -> Bool {
        return keywords.contains { line.contains($0) }
    }
    
    private func containsNumbers(_ line: String) -> Bool {
        return line.rangeOfCharacter(from: .decimalDigits) != nil
    }
    
    private func hasItemCharacteristics(_ line: String) -> Bool {
        // Items typically have alphabetic characters and aren't just numbers/symbols
        let hasLetters = line.rangeOfCharacter(from: .letters) != nil
        let hasAmount = extractAmountFromLine(line) != nil
        let isNotHeader = !containsKeywords(line.lowercased(), keywords: ["total", "tax", "subtotal", "receipt"])
        
        return hasLetters && hasAmount && isNotHeader
    }
    
    private func extractAmountFromLine(_ line: String) -> Decimal? {
        let pattern = #"\$?(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)"#
        
        if let range = line.range(of: pattern, options: .regularExpression) {
            let amountString = String(line[range])
                .replacingOccurrences(of: "$", with: "")
                .replacingOccurrences(of: ",", with: "")
            
            return Decimal(string: amountString)
        }
        
        return nil
    }
}

// MARK: - Receipt Merchant Patterns
class ReceiptMerchantPatterns {
    
    private let commonMerchants = [
        "walmart", "target", "costco", "amazon", "starbucks", "mcdonald's",
        "subway", "home depot", "lowes", "best buy", "cvs", "walgreens"
    ]
    
    private let businessSuffixes = ["inc", "llc", "ltd", "corp", "co", "&", "and"]
    
    func extractMerchantName(from line: String) -> String? {
        let cleanLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Skip empty or very short lines
        guard cleanLine.count > 2 else { return nil }
        
        // Skip lines that are clearly not merchant names
        let skipPatterns = [
            "receipt", "invoice", "bill", "order", "transaction",
            "customer copy", "merchant copy", "thank you", "welcome",
            "store hours", "phone", "address"
        ]
        
        let lowercaseLine = cleanLine.lowercased()
        for pattern in skipPatterns {
            if lowercaseLine.contains(pattern) {
                return nil
            }
        }
        
        // Check if it's a known merchant
        for merchant in commonMerchants {
            if lowercaseLine.contains(merchant) {
                return cleanLine
            }
        }
        
        // Check if it has business characteristics
        if hasBusinessCharacteristics(cleanLine) {
            return cleanLine
        }
        
        return nil
    }
    
    private func hasBusinessCharacteristics(_ line: String) -> Bool {
        let lowercaseLine = line.lowercased()
        
        // Has business suffixes
        for suffix in businessSuffixes {
            if lowercaseLine.contains(suffix) {
                return true
            }
        }
        
        // Has mixed case (typical of business names)
        let hasUppercase = line.rangeOfCharacter(from: .uppercaseLetters) != nil
        let hasLowercase = line.rangeOfCharacter(from: .lowercaseLetters) != nil
        
        // Not all numbers or punctuation
        let hasLetters = line.rangeOfCharacter(from: .letters) != nil
        let notAllNumbers = !line.allSatisfy({ $0.isNumber || $0.isPunctuation || $0.isWhitespace })
        
        return hasLetters && notAllNumbers && (hasUppercase || hasLowercase)
    }
}