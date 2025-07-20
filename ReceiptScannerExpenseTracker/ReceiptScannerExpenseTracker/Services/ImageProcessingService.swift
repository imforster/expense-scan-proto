import Foundation
import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

/// Service for processing and optimizing receipt images
@MainActor
class ImageProcessingService: ObservableObject {
    static let shared = ImageProcessingService()
    
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0.0
    @Published var processingStatus: String = ""
    
    private let context = CIContext()
    
    private init() {}
    
    // MARK: - Public Interface
    
    /// Processes a receipt image with optimization algorithms
    /// - Parameter image: The original receipt image
    /// - Returns: The processed and optimized image
    func processReceiptImage(_ image: UIImage) async throws -> UIImage {
        isProcessing = true
        processingProgress = 0.0
        processingStatus = "Starting image processing..."
        
        defer {
            isProcessing = false
            processingProgress = 0.0
            processingStatus = ""
        }
        
        guard let ciImage = CIImage(image: image) else {
            throw ImageProcessingError.invalidImage
        }
        
        // Step 1: Detect and correct perspective
        processingStatus = "Detecting document edges..."
        processingProgress = 0.2
        let perspectiveCorrectedImage = try await correctPerspective(ciImage)
        
        // Step 2: Enhance contrast and brightness
        processingStatus = "Enhancing image quality..."
        processingProgress = 0.5
        let contrastEnhancedImage = enhanceContrast(perspectiveCorrectedImage)
        
        // Step 3: Reduce noise and sharpen
        processingStatus = "Reducing noise and sharpening..."
        processingProgress = 0.7
        let denoisedImage = reduceNoise(contrastEnhancedImage)
        let sharpenedImage = sharpenImage(denoisedImage)
        
        // Step 4: Optimize for OCR
        processingStatus = "Optimizing for text recognition..."
        processingProgress = 0.9
        let ocrOptimizedImage = optimizeForOCR(sharpenedImage)
        
        // Convert back to UIImage
        processingStatus = "Finalizing..."
        processingProgress = 1.0
        
        guard let cgImage = context.createCGImage(ocrOptimizedImage, from: ocrOptimizedImage.extent) else {
            throw ImageProcessingError.processingFailed("Failed to create final image")
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    /// Quick processing for preview purposes (faster but lower quality)
    /// - Parameter image: The original receipt image
    /// - Returns: The quickly processed image
    func quickProcessReceiptImage(_ image: UIImage) async throws -> UIImage {
        guard let ciImage = CIImage(image: image) else {
            throw ImageProcessingError.invalidImage
        }
        
        // Apply basic enhancements only
        let enhancedImage = enhanceContrast(ciImage)
        let optimizedImage = optimizeForOCR(enhancedImage)
        
        guard let cgImage = context.createCGImage(optimizedImage, from: optimizedImage.extent) else {
            throw ImageProcessingError.processingFailed("Failed to create preview image")
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    // MARK: - Perspective Correction
    
    /// Detects document edges and corrects perspective distortion
    /// - Parameter image: The input CIImage
    /// - Returns: Perspective-corrected CIImage
    private func correctPerspective(_ image: CIImage) async throws -> CIImage {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectRectanglesRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: ImageProcessingError.perspectiveCorrectionFailed(error.localizedDescription))
                    return
                }
                
                guard let observations = request.results as? [VNRectangleObservation],
                      let rectangle = observations.first else {
                    // If no rectangle detected, return original image
                    continuation.resume(returning: image)
                    return
                }
                
                // Apply perspective correction
                let correctedImage = self.applyPerspectiveCorrection(to: image, using: rectangle)
                continuation.resume(returning: correctedImage)
            }
            
            // Configure the request for better document detection
            request.maximumObservations = 1
            request.minimumConfidence = 0.6
            request.minimumAspectRatio = 0.3
            request.maximumAspectRatio = 3.0
            
            let handler = VNImageRequestHandler(ciImage: image, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: ImageProcessingError.perspectiveCorrectionFailed(error.localizedDescription))
            }
        }
    }
    
    /// Applies perspective correction using detected rectangle
    /// - Parameters:
    ///   - image: The input CIImage
    ///   - rectangle: The detected rectangle observation
    /// - Returns: Perspective-corrected CIImage
    private func applyPerspectiveCorrection(to image: CIImage, using rectangle: VNRectangleObservation) -> CIImage {
        let imageSize = image.extent.size
        
        // Convert normalized coordinates to image coordinates
        let topLeft = CGPoint(
            x: rectangle.topLeft.x * imageSize.width,
            y: (1 - rectangle.topLeft.y) * imageSize.height
        )
        let topRight = CGPoint(
            x: rectangle.topRight.x * imageSize.width,
            y: (1 - rectangle.topRight.y) * imageSize.height
        )
        let bottomLeft = CGPoint(
            x: rectangle.bottomLeft.x * imageSize.width,
            y: (1 - rectangle.bottomLeft.y) * imageSize.height
        )
        let bottomRight = CGPoint(
            x: rectangle.bottomRight.x * imageSize.width,
            y: (1 - rectangle.bottomRight.y) * imageSize.height
        )
        
        // Create perspective correction filter
        let perspectiveFilter = CIFilter.perspectiveCorrection()
        perspectiveFilter.inputImage = image
        perspectiveFilter.topLeft = topLeft
        perspectiveFilter.topRight = topRight
        perspectiveFilter.bottomLeft = bottomLeft
        perspectiveFilter.bottomRight = bottomRight
        
        return perspectiveFilter.outputImage ?? image
    }
    
    // MARK: - Image Enhancement
    
    /// Enhances contrast and brightness for better readability
    /// - Parameter image: The input CIImage
    /// - Returns: Contrast-enhanced CIImage
    private func enhanceContrast(_ image: CIImage) -> CIImage {
        // Auto-adjust exposure
        let exposureFilter = CIFilter.exposureAdjust()
        exposureFilter.inputImage = image
        exposureFilter.ev = 0.3 // Slight exposure boost
        
        guard let exposureAdjusted = exposureFilter.outputImage else { return image }
        
        // Enhance contrast
        let contrastFilter = CIFilter.colorControls()
        contrastFilter.inputImage = exposureAdjusted
        contrastFilter.contrast = 1.2
        contrastFilter.brightness = 0.1
        contrastFilter.saturation = 0.8 // Reduce saturation for better OCR
        
        guard let contrastEnhanced = contrastFilter.outputImage else { return exposureAdjusted }
        
        // Apply gamma correction
        let gammaFilter = CIFilter.gammaAdjust()
        gammaFilter.inputImage = contrastEnhanced
        gammaFilter.power = 0.9
        
        return gammaFilter.outputImage ?? contrastEnhanced
    }
    
    /// Reduces noise in the image
    /// - Parameter image: The input CIImage
    /// - Returns: Denoised CIImage
    private func reduceNoise(_ image: CIImage) -> CIImage {
        let noiseReductionFilter = CIFilter.noiseReduction()
        noiseReductionFilter.inputImage = image
        noiseReductionFilter.noiseLevel = 0.02
        noiseReductionFilter.sharpness = 0.4
        
        return noiseReductionFilter.outputImage ?? image
    }
    
    /// Sharpens the image for better text clarity
    /// - Parameter image: The input CIImage
    /// - Returns: Sharpened CIImage
    private func sharpenImage(_ image: CIImage) -> CIImage {
        let sharpenFilter = CIFilter.sharpenLuminance()
        sharpenFilter.inputImage = image
        sharpenFilter.sharpness = 0.6
        
        return sharpenFilter.outputImage ?? image
    }
    
    /// Optimizes the image specifically for OCR processing
    /// - Parameter image: The input CIImage
    /// - Returns: OCR-optimized CIImage
    private func optimizeForOCR(_ image: CIImage) -> CIImage {
        // Convert to grayscale for better OCR performance
        let grayscaleFilter = CIFilter.photoEffectMono()
        grayscaleFilter.inputImage = image
        
        guard let grayscaleImage = grayscaleFilter.outputImage else { return image }
        
        // Apply threshold to create high contrast black and white image
        let thresholdFilter = CIFilter.colorThreshold()
        thresholdFilter.inputImage = grayscaleImage
        thresholdFilter.threshold = 0.5
        
        return thresholdFilter.outputImage ?? grayscaleImage
    }
    
    // MARK: - Utility Methods
    
    /// Calculates the optimal size for processing while maintaining aspect ratio
    /// - Parameters:
    ///   - originalSize: The original image size
    ///   - maxDimension: The maximum dimension for processing
    /// - Returns: The calculated processing size
    private func calculateProcessingSize(originalSize: CGSize, maxDimension: CGFloat = 2048) -> CGSize {
        let aspectRatio = originalSize.width / originalSize.height
        
        if originalSize.width > originalSize.height {
            let width = min(originalSize.width, maxDimension)
            let height = width / aspectRatio
            return CGSize(width: width, height: height)
        } else {
            let height = min(originalSize.height, maxDimension)
            let width = height * aspectRatio
            return CGSize(width: width, height: height)
        }
    }
    
    /// Resizes an image to the specified size
    /// - Parameters:
    ///   - image: The input CIImage
    ///   - size: The target size
    /// - Returns: Resized CIImage
    private func resizeImage(_ image: CIImage, to size: CGSize) -> CIImage {
        let scaleX = size.width / image.extent.width
        let scaleY = size.height / image.extent.height
        let scale = min(scaleX, scaleY)
        
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        return image.transformed(by: transform)
    }
}

// MARK: - Error Types

enum ImageProcessingError: LocalizedError {
    case invalidImage
    case perspectiveCorrectionFailed(String)
    case processingFailed(String)
    case insufficientMemory
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image format"
        case .perspectiveCorrectionFailed(let message):
            return "Perspective correction failed: \(message)"
        case .processingFailed(let message):
            return "Image processing failed: \(message)"
        case .insufficientMemory:
            return "Insufficient memory for image processing"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidImage:
            return "Please try capturing the image again"
        case .perspectiveCorrectionFailed:
            return "Try positioning the receipt more clearly in the frame"
        case .processingFailed:
            return "Please try again or use the original image"
        case .insufficientMemory:
            return "Close other apps and try again"
        }
    }
}