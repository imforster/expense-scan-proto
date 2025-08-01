

import XCTest
@testable import ReceiptScannerExpenseTracker

@MainActor
class OCRServiceTests: XCTestCase {

    var ocrService: OCRService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        ocrService = OCRService()
    }

    override func tearDownWithError() throws {
        ocrService = nil
        try super.tearDownWithError()
    }

    // MARK: - Image Pre-processing Tests

    func testPreprocessImage_withValidColorImage_returnsGrayscaleImage() async throws {
        // Given
        let colorImage = UIImage(systemName: "photo.on.rectangle")! // Using a system image as a placeholder
        
        // When
        let processedCGImage = await ocrService.preprocessImage(colorImage)
        
        // Then
        XCTAssertNotNil(processedCGImage, "The processed image should not be nil.")
        
        // Verify that the image is grayscale
        XCTAssertEqual(processedCGImage?.colorSpace?.model, .monochrome, "The processed image should be grayscale.")
    }

    func testPreprocessImage_withNilImage_returnsNil() async {
        // Given
        let nilImage: UIImage? = nil
        
        // When
        let processedCGImage = await ocrService.preprocessImage(nilImage!)
        
        // Then
        XCTAssertNil(processedCGImage, "The processed image should be nil for a nil input.")
    }

    // MARK: - Language Detection Tests

    func testDetectLanguages_withEnglishText_returnsEnglish() async throws {
        // Given
        // Create a sample image with English text
        let image = createImage(withText: "Hello, world!")
        
        // When
        let languages = await ocrService.detectLanguages(in: image)
        
        // Then
        XCTAssertFalse(languages.isEmpty, "Should detect at least one language.")
        XCTAssertTrue(languages.contains("en-US"), "Should detect English (en-US).")
    }

    func testDetectLanguages_withNoText_returnsEmptyArray() async {
        // Given
        let blankImage = UIImage(color: .white, size: CGSize(width: 100, height: 100))!
        
        // When
        let languages = await ocrService.detectLanguages(in: blankImage)
        
        // Then
        XCTAssertTrue(languages.isEmpty, "Should not detect any language in a blank image.")
    }

    // MARK: - ReceiptParser (Placeholder) Tests

    func testParseReceiptData_withSampleText_returnsParsedData() async throws {
        // Given
        let sampleText = """
        Sample Merchant
        123 Main Street
        Date: 07/30/2025
        Item 1 .................... $10.00
        Item 2 .................... $5.50
        Tax ....................... $1.24
        Total ..................... $16.74
        """
        
        // When
        let receiptData = try await ocrService.parseReceiptData(sampleText)
        
        // Then
        XCTAssertEqual(receiptData.merchantName, "Sample Merchant", "Merchant name should be the first line.")
        XCTAssertEqual(receiptData.totalAmount, Decimal(string: "16.74"), "Total amount should be extracted correctly.")
        XCTAssertEqual(receiptData.taxAmount, Decimal(string: "1.24"), "Tax amount should be extracted correctly.")
    }

    // MARK: - Integration Test

    func testEndToEnd_fromImageToReceiptData() async throws {
        // Given
        let receiptImage = createImage(withText: "Test Store\nTotal: $12.34")
        
        // When
        let extractedText = try await ocrService.extractTextFromImage(receiptImage)
        let receiptData = try await ocrService.parseReceiptData(extractedText)
        
        // Then
        XCTAssertNotNil(receiptData, "The final receipt data should not be nil.")
        XCTAssert(receiptData.totalAmount > 0, "Total amount should be greater than zero.")
    }

    // MARK: - Helper Methods
    
    private func createImage(withText text: String) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 100))
        let img = renderer.image { ctx in
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 18),
                .paragraphStyle: paragraphStyle,
                .foregroundColor: UIColor.black
            ]
            
            text.draw(with: CGRect(x: 0, y: 20, width: 200, height: 80), options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
        }
        return img
    }
}

extension UIImage {
    public convenience init?(color: UIColor, size: CGSize = CGSize(width: 1, height: 1)) {
        let rect = CGRect(origin: .zero, size: size)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
        color.setFill()
        UIRectFill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        guard let cgImage = image?.cgImage else { return nil }
        self.init(cgImage: cgImage)
    }
}
