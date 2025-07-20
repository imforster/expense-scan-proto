import Foundation
import UIKit

/// Manages image storage and retrieval operations
class ImageManager {
    static let shared = ImageManager()
    
    private let receiptImageDirectory: URL
    private let imageProcessingService = ImageProcessingService.shared
    
    private init() {
        // Setup receipt image storage directory
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        receiptImageDirectory = documentsDirectory.appendingPathComponent("ReceiptImages", isDirectory: true)
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: receiptImageDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: receiptImageDirectory, withIntermediateDirectories: true)
            } catch {
                print("Error creating receipt image directory: \(error)")
            }
        }
        
        // Enable data protection for the directory
        enableDataProtection()
    }
    
    // MARK: - Image Management
    
    /// Saves a receipt image to the file system and returns the URL
    /// - Parameter image: The image to save
    /// - Returns: The URL where the image is saved
    func saveReceiptImage(_ image: UIImage) -> URL? {
        let imageId = UUID().uuidString
        let imageURL = receiptImageDirectory.appendingPathComponent("\(imageId).jpg")
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("Failed to convert image to JPEG data")
            return nil
        }
        
        do {
            try imageData.write(to: imageURL)
            
            // Apply data protection to the image file
            try FileManager.default.setAttributes(
                [FileAttributeKey.protectionKey: FileProtectionType.complete],
                ofItemAtPath: imageURL.path
            )
            
            return imageURL
        } catch {
            print("Error saving receipt image: \(error)")
            return nil
        }
    }
    
    /// Saves a processed receipt image to the file system and returns the URL
    /// - Parameters:
    ///   - image: The processed image to save
    ///   - originalImageURL: The URL of the original image
    /// - Returns: The URL where the processed image is saved
    func saveProcessedReceiptImage(_ image: UIImage, originalImageURL: URL) -> URL? {
        let originalFilename = originalImageURL.deletingPathExtension().lastPathComponent
        let processedImageURL = receiptImageDirectory.appendingPathComponent("\(originalFilename)_processed.jpg")
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("Failed to convert processed image to JPEG data")
            return nil
        }
        
        do {
            try imageData.write(to: processedImageURL)
            
            // Apply data protection to the image file
            try FileManager.default.setAttributes(
                [FileAttributeKey.protectionKey: FileProtectionType.complete],
                ofItemAtPath: processedImageURL.path
            )
            
            return processedImageURL
        } catch {
            print("Error saving processed receipt image: \(error)")
            return nil
        }
    }
    
    /// Loads a receipt image from the file system
    /// - Parameter url: The URL of the image to load
    /// - Returns: The loaded image, or nil if loading failed
    func loadReceiptImage(from url: URL) -> UIImage? {
        do {
            let imageData = try Data(contentsOf: url)
            return UIImage(data: imageData)
        } catch {
            print("Error loading receipt image: \(error)")
            return nil
        }
    }
    
    /// Saves image data to the file system and returns the URL
    /// - Parameter imageData: The image data to save
    /// - Returns: The URL where the image is saved
    func saveImageData(_ imageData: Data) -> URL? {
        let imageId = UUID().uuidString
        let imageURL = receiptImageDirectory.appendingPathComponent("\(imageId).jpg")
        
        do {
            try imageData.write(to: imageURL)
            
            // Apply data protection to the image file
            try FileManager.default.setAttributes(
                [FileAttributeKey.protectionKey: FileProtectionType.complete],
                ofItemAtPath: imageURL.path
            )
            
            return imageURL
        } catch {
            print("Error saving image data: \(error)")
            return nil
        }
    }
    
    /// Loads image data from the file system
    /// - Parameter url: The URL of the image to load
    /// - Returns: The loaded image data, or nil if loading failed
    func loadImageData(from url: URL) -> Data? {
        do {
            return try Data(contentsOf: url)
        } catch {
            print("Error loading image data: \(error)")
            return nil
        }
    }
    
    /// Deletes a receipt image from the file system
    /// - Parameter url: The URL of the image to delete
    /// - Returns: True if deletion was successful, false otherwise
    func deleteReceiptImage(at url: URL) -> Bool {
        do {
            try FileManager.default.removeItem(at: url)
            return true
        } catch {
            print("Error deleting receipt image: \(error)")
            return false
        }
    }
    
    // MARK: - Image Processing Integration
    
    /// Processes and saves a receipt image with optimization
    /// - Parameter image: The original receipt image
    /// - Returns: A tuple containing the original image URL and processed image URL
    @MainActor
    func processAndSaveReceiptImage(_ image: UIImage) async throws -> (originalURL: URL, processedURL: URL?) {
        // Save the original image first
        guard let originalURL = saveReceiptImage(image) else {
            throw ImageProcessingError.processingFailed("Failed to save original image")
        }
        
        do {
            // Process the image
            let processedImage = try await imageProcessingService.processReceiptImage(image)
            
            // Save the processed image
            let processedURL = saveProcessedReceiptImage(processedImage, originalImageURL: originalURL)
            
            return (originalURL: originalURL, processedURL: processedURL)
        } catch {
            // If processing fails, still return the original image URL
            print("Image processing failed: \(error)")
            return (originalURL: originalURL, processedURL: nil)
        }
    }
    
    /// Quickly processes and saves a receipt image for preview
    /// - Parameter image: The original receipt image
    /// - Returns: A tuple containing the original image URL and quickly processed image URL
    @MainActor
    func quickProcessAndSaveReceiptImage(_ image: UIImage) async throws -> (originalURL: URL, processedURL: URL?) {
        // Save the original image first
        guard let originalURL = saveReceiptImage(image) else {
            throw ImageProcessingError.processingFailed("Failed to save original image")
        }
        
        do {
            // Quick process the image
            let processedImage = try await imageProcessingService.quickProcessReceiptImage(image)
            
            // Save the processed image
            let processedURL = saveProcessedReceiptImage(processedImage, originalImageURL: originalURL)
            
            return (originalURL: originalURL, processedURL: processedURL)
        } catch {
            // If processing fails, still return the original image URL
            print("Quick image processing failed: \(error)")
            return (originalURL: originalURL, processedURL: nil)
        }
    }
    
    // MARK: - Data Protection
    
    /// Enables data protection for the receipt image directory
    private func enableDataProtection() {
        do {
            // Set data protection for the directory
            try FileManager.default.setAttributes(
                [FileAttributeKey.protectionKey: FileProtectionType.complete],
                ofItemAtPath: receiptImageDirectory.path
            )
            
            // Exclude from backup
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            
            var directoryURL = receiptImageDirectory
            try directoryURL.setResourceValues(resourceValues)
        } catch {
            print("Error setting data protection for image directory: \(error)")
        }
    }
}