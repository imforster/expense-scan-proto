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

// MARK: - OCR Service Implementation
class OCRService: OCRServiceProtocol {
    
    // MARK: - Properties
    private let receiptParser = ReceiptParser()
    
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
        // 1. Pre-process the image for better OCR accuracy
        let preprocessedImage = await preprocessImage(image)
        
        guard let cgImage = preprocessedImage else {
            throw OCRError.imageProcessingFailed
        }
        
        // 2. Detect language for better recognition
        let detectedLanguages = await detectLanguages(in: image)
        
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
                    // Get top candidate for better accuracy
                    return observation.topCandidates(1).first?.string
                }
                
                if recognizedStrings.isEmpty {
                    continuation.resume(throwing: OCRError.noTextFound)
                } else {
                    let fullText = recognizedStrings.joined(separator: "\n")
                    continuation.resume(returning: fullText)
                }
            }
            
            // Configure the request for maximum accuracy
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.minimumTextHeight = 0.015 // Adjust based on pre-processing
            
            // Use detected languages, fallback to English
            if !detectedLanguages.isEmpty {
                request.recognitionLanguages = detectedLanguages
            } else {
                request.recognitionLanguages = ["en-US"]
            }
            request.automaticallyDetectsLanguage = false
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Image Pre-processing
    private func preprocessImage(_ image: UIImage) async -> CGImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        let context = CIContext(options: nil)

        // 1. Apply Grayscale Filter
        let grayscaleFilter = CIFilter(name: "CIPhotoEffectNoir")
        grayscaleFilter?.setValue(ciImage, forKey: kCIInputImageKey)
        
        // 2. Increase Contrast
        let colorControlsFilter = CIFilter(name: "CIColorControls")
        colorControlsFilter?.setValue(grayscaleFilter?.outputImage, forKey: kCIInputImageKey)
        colorControlsFilter?.setValue(1.5, forKey: kCIInputContrastKey) // Adjust contrast
        
        // 3. Sharpen the image
        let sharpenFilter = CIFilter(name: "CISharpenLuminance")
        sharpenFilter?.setValue(colorControlsFilter?.outputImage, forKey: kCIInputImageKey)
        sharpenFilter?.setValue(0.8, forKey: kCIInputSharpnessKey) // Adjust sharpness

        guard let outputImage = sharpenFilter?.outputImage else { return nil }
        
        // Render the output CIImage to a CGImage
        return context.createCGImage(outputImage, from: outputImage.extent)
    }
    
    // MARK: - Language Detection
    private func detectLanguages(in image: UIImage) async -> [String] {
        guard let cgImage = image.cgImage else { return [] }
        
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .fast // Use fast for language detection
            
            do {
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try handler.perform([request])
                
                if let languages = try? VNRecognizeTextRequest.supportedRecognitionLanguages(for: .accurate, revision: VNRecognizeTextRequestRevision1).first {
                    continuation.resume(returning: [languages])
                } else {
                    continuation.resume(returning: [])
                }
            } catch {
                continuation.resume(returning: [])
            }
        }
    }
    
    // MARK: - Receipt Data Parsing
    func parseReceiptData(_ text: String) async throws -> ReceiptData {
        do {
            let parsedData = try await receiptParser.parse(text: text)
            return parsedData
        } catch {
            throw OCRError.parsingFailed(error.localizedDescription)
        }
    }
}

// MARK: - Core ML Receipt Parser (Placeholder)
// This class simulates the interface to a real Core ML model.
// Replace this with the actual model loading and prediction logic.
class ReceiptParser {
    
    // In a real implementation, you would load your Core ML model here.
    // let model = try? ReceiptParserModel(configuration: MLModelConfiguration())
    
    func parse(text: String) async throws -> ReceiptData {
        // This is a placeholder implementation.
        // A real implementation would pass the text to the Core ML model
        // and get structured data back.
        
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // --- Placeholder Logic ---
        let merchantName = lines.first ?? "Unknown Merchant"
        let date = Date() // Placeholder
        let totalAmount = extractTotalAmount(from: lines) ?? Decimal.zero
        let taxAmount = extractTaxAmount(from: lines)
        // --- End Placeholder ---
        
        return ReceiptData(
            merchantName: merchantName,
            date: date,
            totalAmount: totalAmount,
            taxAmount: taxAmount,
            items: nil, // Item parsing would also be handled by the model
            paymentMethod: nil,
            receiptNumber: nil,
            confidence: 0.9 // Placeholder confidence
        )
    }
    
    // Simplified extraction logic for the placeholder
    private func extractTotalAmount(from lines: [String]) -> Decimal? {
        for line in lines.reversed() {
            if line.lowercased().contains("total") {
                return extractAmountFromLine(line)
            }
        }
        return lines.compactMap { extractAmountFromLine($0) }.max()
    }
    
    private func extractTaxAmount(from lines: [String]) -> Decimal? {
        for line in lines {
            if line.lowercased().contains("tax") {
                return extractAmountFromLine(line)
            }
        }
        return nil
    }
    
    private func extractAmountFromLine(_ line: String) -> Decimal? {
        let pattern = #"[\$€£]?\s*(\d{1,3}(?:[,.]\d{3})*(?:[.,]\d{2})?)"#
        if let range = line.range(of: pattern, options: .regularExpression) {
            let amountString = String(line[range])
                .replacingOccurrences(of: "$", with: "")
                .replacingOccurrences(of: "€", with: "")
                .replacingOccurrences(of: "£", with: "")
                .replacingOccurrences(of: ",", with: ".") // Normalize decimal separator
                .trimmingCharacters(in: .whitespaces)
            return Decimal(string: amountString)
        }
        return nil
    }
}