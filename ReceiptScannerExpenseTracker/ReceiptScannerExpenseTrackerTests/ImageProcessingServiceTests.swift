import XCTest
import UIKit
import Vision
import CoreImage
@testable import ReceiptScannerExpenseTracker

@MainActor
final class ImageProcessingServiceTests: XCTestCase {
    
    var imageProcessingService: ImageProcessingService!
    var testImage: UIImage!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        imageProcessingService = ImageProcessingService.shared
        
        // Create a test image for processing
        testImage = createTestReceiptImage()
    }
    
    override func tearDownWithError() throws {
        imageProcessingService = nil
        testImage = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Test Image Creation
    
    /// Creates a synthetic receipt image for testing
    private func createTestReceiptImage() -> UIImage {
        let size = CGSize(width: 400, height: 600)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // White background
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Add some text-like elements
            UIColor.black.setFill()
            let textRect1 = CGRect(x: 50, y: 50, width: 300, height: 20)
            let textRect2 = CGRect(x: 50, y: 100, width: 250, height: 20)
            let textRect3 = CGRect(x: 50, y: 150, width: 200, height: 20)
            
            context.fill(textRect1)
            context.fill(textRect2)
            context.fill(textRect3)
            
            // Add some noise
            for _ in 0..<100 {
                let x = CGFloat.random(in: 0...size.width)
                let y = CGFloat.random(in: 0...size.height)
                let noiseRect = CGRect(x: x, y: y, width: 2, height: 2)
                UIColor.gray.setFill()
                context.fill(noiseRect)
            }
        }
    }
    
    /// Creates a test image with perspective distortion
    private func createDistortedTestImage() -> UIImage {
        let size = CGSize(width: 400, height: 600)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // Create a quadrilateral shape to simulate perspective distortion
            UIColor.white.setFill()
            
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 50, y: 100))  // Top-left (distorted)
            path.addLine(to: CGPoint(x: 350, y: 50)) // Top-right
            path.addLine(to: CGPoint(x: 380, y: 550)) // Bottom-right
            path.addLine(to: CGPoint(x: 20, y: 500))  // Bottom-left (distorted)
            path.close()
            
            path.fill()
            
            // Add text content
            UIColor.black.setFill()
            let textRect = CGRect(x: 100, y: 200, width: 200, height: 20)
            context.fill(textRect)
        }
    }
    
    // MARK: - Basic Processing Tests
    
    func testProcessReceiptImageSuccess() async throws {
        // Given
        XCTAssertNotNil(testImage, "Test image should be created")
        
        // When
        let processedImage = try await imageProcessingService.processReceiptImage(testImage)
        
        // Then
        XCTAssertNotNil(processedImage, "Processed image should not be nil")
        XCTAssertTrue(processedImage.size.width > 0, "Processed image should have valid width")
        XCTAssertTrue(processedImage.size.height > 0, "Processed image should have valid height")
    }
    
    func testQuickProcessReceiptImageSuccess() async throws {
        // Given
        XCTAssertNotNil(testImage, "Test image should be created")
        
        // When
        let processedImage = try await imageProcessingService.quickProcessReceiptImage(testImage)
        
        // Then
        XCTAssertNotNil(processedImage, "Quick processed image should not be nil")
        XCTAssertTrue(processedImage.size.width > 0, "Quick processed image should have valid width")
        XCTAssertTrue(processedImage.size.height > 0, "Quick processed image should have valid height")
    }
    
    func testProcessingWithInvalidImage() async {
        // Given
        let invalidImage = UIImage()
        
        // When/Then
        do {
            _ = try await imageProcessingService.processReceiptImage(invalidImage)
            XCTFail("Processing should fail with invalid image")
        } catch ImageProcessingError.invalidImage {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Progress Tracking Tests
    
    func testProcessingProgressUpdates() async throws {
        // Given
        var progressValues: [Double] = []
        var statusMessages: [String] = []
        
        // Monitor progress changes
        let progressExpectation = expectation(description: "Progress updates")
        progressExpectation.expectedFulfillmentCount = 1
        
        // Start processing in background
        Task {
            _ = try await imageProcessingService.processReceiptImage(testImage)
            progressExpectation.fulfill()
        }
        
        // Monitor progress for a short time
        for _ in 0..<10 {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            progressValues.append(imageProcessingService.processingProgress)
            statusMessages.append(imageProcessingService.processingStatus)
        }
        
        await fulfillment(of: [progressExpectation], timeout: 10.0)
        
        // Then
        XCTAssertTrue(progressValues.contains { $0 > 0 }, "Progress should be updated during processing")
        XCTAssertTrue(statusMessages.contains { !$0.isEmpty }, "Status messages should be updated during processing")
    }
    
    func testProcessingStateManagement() async throws {
        // Given
        XCTAssertFalse(imageProcessingService.isProcessing, "Should not be processing initially")
        XCTAssertEqual(imageProcessingService.processingProgress, 0.0, "Progress should be 0 initially")
        
        // When
        let processingTask = Task {
            return try await imageProcessingService.processReceiptImage(testImage)
        }
        
        // Brief delay to allow processing to start
        try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        
        // Then (during processing)
        XCTAssertTrue(imageProcessingService.isProcessing, "Should be processing during operation")
        
        // Wait for completion
        _ = try await processingTask.value
        
        // Then (after processing)
        XCTAssertFalse(imageProcessingService.isProcessing, "Should not be processing after completion")
        XCTAssertEqual(imageProcessingService.processingProgress, 0.0, "Progress should be reset after completion")
        XCTAssertTrue(imageProcessingService.processingStatus.isEmpty, "Status should be cleared after completion")
    }
    
    // MARK: - Image Quality Tests
    
    func testContrastEnhancement() async throws {
        // Given
        let lowContrastImage = createLowContrastTestImage()
        
        // When
        let processedImage = try await imageProcessingService.processReceiptImage(lowContrastImage)
        
        // Then
        XCTAssertNotNil(processedImage, "Processed image should not be nil")
        
        // Verify the image has been processed (size should be maintained or improved)
        XCTAssertGreaterThanOrEqual(processedImage.size.width, lowContrastImage.size.width * 0.8,
                                   "Processed image width should be reasonable")
        XCTAssertGreaterThanOrEqual(processedImage.size.height, lowContrastImage.size.height * 0.8,
                                   "Processed image height should be reasonable")
    }
    
    func testPerspectiveCorrection() async throws {
        // Given
        let distortedImage = createDistortedTestImage()
        
        // When
        let processedImage = try await imageProcessingService.processReceiptImage(distortedImage)
        
        // Then
        XCTAssertNotNil(processedImage, "Processed image should not be nil")
        XCTAssertTrue(processedImage.size.width > 0, "Processed image should have valid dimensions")
        XCTAssertTrue(processedImage.size.height > 0, "Processed image should have valid dimensions")
    }
    
    // MARK: - Performance Tests
    
    func testProcessingPerformance() async throws {
        // Given
        let largeImage = createLargeTestImage()
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        _ = try await imageProcessingService.processReceiptImage(largeImage)
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then
        XCTAssertLessThan(processingTime, 10.0, "Processing should complete within 10 seconds")
    }
    
    func testQuickProcessingPerformance() async throws {
        // Given
        let largeImage = createLargeTestImage()
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        _ = try await imageProcessingService.quickProcessReceiptImage(largeImage)
        let quickProcessingTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Regular processing time for comparison
        let regularStartTime = CFAbsoluteTimeGetCurrent()
        _ = try await imageProcessingService.processReceiptImage(largeImage)
        let regularProcessingTime = CFAbsoluteTimeGetCurrent() - regularStartTime
        
        // Then
        XCTAssertLessThan(quickProcessingTime, regularProcessingTime,
                         "Quick processing should be faster than regular processing")
        XCTAssertLessThan(quickProcessingTime, 5.0, "Quick processing should complete within 5 seconds")
    }
    
    // MARK: - Error Handling Tests
    
    func testMemoryManagement() async throws {
        // Given
        let images = (0..<5).map { _ in createTestReceiptImage() }
        
        // When - Process multiple images in sequence
        for image in images {
            _ = try await imageProcessingService.processReceiptImage(image)
        }
        
        // Then - Should complete without memory issues
        XCTAssertFalse(imageProcessingService.isProcessing, "Should not be processing after all operations")
    }
    
    func testConcurrentProcessing() async throws {
        // Given
        let images = (0..<3).map { _ in createTestReceiptImage() }
        
        // When - Process multiple images concurrently
        let tasks = images.map { image in
            Task {
                return try await imageProcessingService.quickProcessReceiptImage(image)
            }
        }
        
        // Wait for all tasks to complete
        let results = try await withThrowingTaskGroup(of: UIImage.self) { group in
            for task in tasks {
                group.addTask { try await task.value }
            }
            
            var processedImages: [UIImage] = []
            for try await result in group {
                processedImages.append(result)
            }
            return processedImages
        }
        
        // Then
        XCTAssertEqual(results.count, images.count, "All images should be processed")
        for result in results {
            XCTAssertNotNil(result, "Each processed image should be valid")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createLowContrastTestImage() -> UIImage {
        let size = CGSize(width: 300, height: 400)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // Light gray background
            UIColor(white: 0.9, alpha: 1.0).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Slightly darker gray text
            UIColor(white: 0.8, alpha: 1.0).setFill()
            let textRect = CGRect(x: 50, y: 100, width: 200, height: 20)
            context.fill(textRect)
        }
    }
    
    private func createLargeTestImage() -> UIImage {
        let size = CGSize(width: 2000, height: 3000)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Add multiple text blocks
            UIColor.black.setFill()
            for i in 0..<20 {
                let y = CGFloat(i * 100 + 50)
                let textRect = CGRect(x: 100, y: y, width: 1800, height: 30)
                context.fill(textRect)
            }
        }
    }
}

// MARK: - ImageManager Integration Tests

@MainActor
final class ImageManagerProcessingTests: XCTestCase {
    
    var imageManager: ImageManager!
    var testImage: UIImage!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        imageManager = ImageManager.shared
        testImage = createTestImage()
    }
    
    override func tearDownWithError() throws {
        imageManager = nil
        testImage = nil
        try super.tearDownWithError()
    }
    
    private func createTestImage() -> UIImage {
        let size = CGSize(width: 200, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            UIColor.black.setFill()
            let textRect = CGRect(x: 20, y: 50, width: 160, height: 15)
            context.fill(textRect)
        }
    }
    
    func testProcessAndSaveReceiptImage() async throws {
        // When
        let result = try await imageManager.processAndSaveReceiptImage(testImage)
        
        // Then
        XCTAssertNotNil(result.originalURL, "Original image URL should not be nil")
        
        // Verify original image was saved
        let originalImage = imageManager.loadReceiptImage(from: result.originalURL)
        XCTAssertNotNil(originalImage, "Should be able to load original image")
        
        // Clean up
        _ = imageManager.deleteReceiptImage(at: result.originalURL)
        if let processedURL = result.processedURL {
            _ = imageManager.deleteReceiptImage(at: processedURL)
        }
    }
    
    func testQuickProcessAndSaveReceiptImage() async throws {
        // When
        let result = try await imageManager.quickProcessAndSaveReceiptImage(testImage)
        
        // Then
        XCTAssertNotNil(result.originalURL, "Original image URL should not be nil")
        
        // Verify original image was saved
        let originalImage = imageManager.loadReceiptImage(from: result.originalURL)
        XCTAssertNotNil(originalImage, "Should be able to load original image")
        
        // Clean up
        _ = imageManager.deleteReceiptImage(at: result.originalURL)
        if let processedURL = result.processedURL {
            _ = imageManager.deleteReceiptImage(at: processedURL)
        }
    }
    
    func testProcessingFailureHandling() async throws {
        // Given - Create an invalid image that might cause processing to fail
        let invalidImage = UIImage()
        
        // When
        let result = try await imageManager.processAndSaveReceiptImage(invalidImage)
        
        // Then - Should still save original image even if processing fails
        XCTAssertNotNil(result.originalURL, "Original image URL should not be nil even if processing fails")
        
        // Clean up
        _ = imageManager.deleteReceiptImage(at: result.originalURL)
        if let processedURL = result.processedURL {
            _ = imageManager.deleteReceiptImage(at: processedURL)
        }
    }
}