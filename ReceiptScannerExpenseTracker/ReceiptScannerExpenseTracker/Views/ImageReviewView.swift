import SwiftUI

/// View for reviewing captured receipt images before processing
struct ImageReviewView: View {
    let image: UIImage
    let onConfirm: (UIImage) -> Void
    let onRetake: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var imageScale: CGFloat = 1.0
    @State private var imageOffset: CGSize = .zero
    @State private var lastScaleValue: CGFloat = 1.0
    @State private var isProcessing = false
    @State private var showProcessingOptions = false
    @State private var showReceiptReview = false
    @State private var extractedReceiptData: ReceiptData?
    @State private var processedImage: UIImage?
    @State private var showError = false
    @State private var errorMessage = ""
    
    @StateObject private var imageProcessingService = ImageProcessingService.shared
    private let ocrService = OCRService()
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                // Image display with zoom and pan
                GeometryReader { geometry in
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(imageScale)
                        .offset(imageOffset)
                        .gesture(
                            SimultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let delta = value / lastScaleValue
                                        lastScaleValue = value
                                        let newScale = imageScale * delta
                                        imageScale = min(max(newScale, 0.5), 3.0)
                                    }
                                    .onEnded { _ in
                                        lastScaleValue = 1.0
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            if imageScale < 1.0 {
                                                imageScale = 1.0
                                                imageOffset = .zero
                                            }
                                        }
                                    },
                                
                                DragGesture()
                                    .onChanged { value in
                                        if imageScale > 1.0 {
                                            imageOffset = value.translation
                                        }
                                    }
                                    .onEnded { _ in
                                        if imageScale <= 1.0 {
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                imageOffset = .zero
                                            }
                                        }
                                    }
                            )
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                if imageScale > 1.0 {
                                    imageScale = 1.0
                                    imageOffset = .zero
                                } else {
                                    imageScale = 2.0
                                }
                            }
                        }
                }
                .clipped()
                
                // Instructions overlay
                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Review Your Receipt")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("Double-tap to zoom • Pinch to scale")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    Spacer()
                    
                    // Action buttons
                    if !isProcessing {
                        HStack(spacing: 20) {
                            // Retake button
                            Button(action: {
                                onRetake()
                                dismiss()
                            }) {
                                VStack(spacing: 8) {
                                    Image(systemName: "camera.rotate")
                                        .font(.system(size: 24, weight: .medium))
                                        .foregroundColor(.white)
                                    
                                    Text("Retake")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 20)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(12)
                            }
                            .accessibilityLabel("Retake photo")
                            
                            // Process & Extract button
                            Button(action: {
                                processAndExtractReceipt()
                            }) {
                                VStack(spacing: 8) {
                                    Image(systemName: "doc.text.magnifyingglass")
                                        .font(.system(size: 24, weight: .medium))
                                        .foregroundColor(.white)
                                    
                                    Text("Extract Data")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(12)
                            }
                            .accessibilityLabel("Process and extract receipt data")
                            
                            // Use as-is button
                            Button(action: {
                                processAndUseImage()
                            }) {
                                VStack(spacing: 8) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 24, weight: .medium))
                                        .foregroundColor(.white)
                                    
                                    Text("Use As-Is")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(12)
                            }
                            .accessibilityLabel("Use photo without processing")
                        }
                        .padding(.bottom, 40)
                    } else {
                        // Processing indicator
                        VStack(spacing: 16) {
                            ProgressView(value: imageProcessingService.processingProgress)
                                .progressViewStyle(LinearProgressViewStyle(tint: .white))
                                .frame(width: 200)
                            
                            VStack(spacing: 4) {
                                Text("Processing Image...")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text(imageProcessingService.processingStatus)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.vertical, 20)
                        .padding(.horizontal, 30)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(16)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .sheet(isPresented: $showReceiptReview) {
                if let receiptData = extractedReceiptData,
                   let processedImage = processedImage {
                    ReceiptReviewView(receiptData: receiptData, originalImage: processedImage) {
                        // When receipt is saved, dismiss the entire flow
                        onConfirm(processedImage)
                    }
                }
            }
            .alert("Processing Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Processes the image and extracts receipt data using OCR
    private func processAndExtractReceipt() {
        isProcessing = true
        
        Task {
            do {
                // First, process the image for better OCR results
                let processedImage = try await imageProcessingService.processReceiptImage(image)
                
                // Extract text using OCR
                let extractedText = try await ocrService.extractTextFromImage(processedImage)
                
                // Parse the extracted text into structured receipt data
                let receiptData = try await ocrService.parseReceiptData(extractedText)
                
                await MainActor.run {
                    self.processedImage = processedImage
                    self.extractedReceiptData = receiptData
                    self.isProcessing = false
                    self.showReceiptReview = true
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.errorMessage = "Failed to extract receipt data: \(error.localizedDescription)"
                    self.showError = true
                }
            }
        }
    }
    
    /// Processes the image and confirms it for use
    private func processAndUseImage() {
        isProcessing = true
        
        Task {
            do {
                let processedImage = try await imageProcessingService.processReceiptImage(image)
                await MainActor.run {
                    self.processedImage = processedImage
    
                    self.extractedReceiptData =  ReceiptData(merchantName: "Manual Entry", date: Date(), totalAmount: 0, taxAmount: nil,
                        items: [], paymentMethod: nil, receiptNumber: nil, confidence: 0.0)
                    isProcessing = false
                    self.showReceiptReview = true
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    // If processing fails, use the original image
                    onConfirm(image)
                }
            }
        }
    }
}

#Preview {
    ImageReviewView(
        image: UIImage(systemName: "doc.text") ?? UIImage(),
        onConfirm: { _ in },
        onRetake: { }
    )
}
