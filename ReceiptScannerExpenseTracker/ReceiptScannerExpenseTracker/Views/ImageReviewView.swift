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
    
    @StateObject private var imageProcessingService = ImageProcessingService.shared
    
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
                            
                            // Process & Use button
                            Button(action: {
                                processAndUseImage()
                            }) {
                                VStack(spacing: 8) {
                                    Image(systemName: "wand.and.stars")
                                        .font(.system(size: 24, weight: .medium))
                                        .foregroundColor(.black)
                                    
                                    Text("Process & Use")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.black)
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .background(Color.white)
                                .cornerRadius(12)
                            }
                            .accessibilityLabel("Process and use this photo")
                            
                            // Use as-is button
                            Button(action: {
                                onConfirm(image)
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
        }
    }
    
    // MARK: - Private Methods
    
    /// Processes the image and confirms it for use
    private func processAndUseImage() {
        isProcessing = true
        
        Task {
            do {
                let processedImage = try await imageProcessingService.processReceiptImage(image)
                await MainActor.run {
                    isProcessing = false
                    onConfirm(processedImage)
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