import SwiftUI
import AVFoundation

/// Main camera capture view for scanning receipts
struct CameraCaptureView: View {
    @StateObject private var cameraService = CameraService.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var isCapturing = false
    @State private var showingImageReview = false
    @State private var capturedImage: UIImage?
    @State private var focusLocation: CGPoint?
    @State private var showingPermissionAlert = false
    @State private var showingErrorAlert = false
    
    let onImageCaptured: (UIImage) -> Void
    
    init(onImageCaptured: @escaping (UIImage) -> Void) {
        self.onImageCaptured = onImageCaptured
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if cameraService.isAuthorized {
                cameraView
            } else {
                permissionView
            }
            
            // Focus indicator
            if let focusLocation = focusLocation {
                FocusIndicatorView()
                    .position(focusLocation)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            setupCamera()
        }
        .onDisappear {
            cameraService.stopSession()
        }
        .alert("Camera Permission Required", isPresented: $showingPermissionAlert) {
            Button("Settings") {
                openSettings()
            }
            Button("Cancel", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("Please enable camera access in Settings to scan receipts.")
        }
        .alert("Camera Error", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(cameraService.errorMessage ?? "An unknown error occurred.")
        }
        .sheet(isPresented: $showingImageReview) {
            if let image = capturedImage {
                ImageReviewView(
                    image: image,
                    onConfirm: { confirmedImage in
                        onImageCaptured(confirmedImage)
                        dismiss()
                    },
                    onRetake: {
                        capturedImage = nil
                        showingImageReview = false
                    }
                )
            }
        }
    }
    
    private var cameraView: some View {
        ZStack {
            // Camera preview
            CameraPreviewView(session: cameraService.session) { point in
                handleFocusTap(at: point)
            }
            .ignoresSafeArea()
            
            // Camera overlay UI
            VStack {
                // Top controls
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Close camera")
                    
                    Spacer()
                    
                    Button(action: { cameraService.toggleTorch() }) {
                        Image(systemName: cameraService.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(cameraService.isTorchOn ? "Turn off flash" : "Turn on flash")
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                Spacer()
                
                // Receipt frame guide
                receiptFrameGuide
                
                Spacer()
                
                // Bottom controls
                HStack {
                    Spacer()
                    
                    // Capture button
                    Button(action: capturePhoto) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 80, height: 80)
                            
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 90, height: 90)
                            
                            if isCapturing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                    .scaleEffect(1.2)
                            }
                        }
                    }
                    .disabled(isCapturing || !cameraService.isSessionRunning)
                    .scaleEffect(isCapturing ? 0.9 : 1.0)
                    .animation(reduceMotion ? .none : .easeInOut(duration: 0.1), value: isCapturing)
                    .accessibilityLabel("Capture receipt photo")
                    
                    Spacer()
                }
                .padding(.bottom, 40)
            }
            
            // Instructions overlay
            if !cameraService.isSessionRunning {
                VStack {
                    Spacer()
                    Text("Initializing camera...")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                    Spacer()
                }
            }
        }
    }
    
    private var receiptFrameGuide: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(Color.white.opacity(0.8), lineWidth: 2)
            .frame(width: 280, height: 350)
            .overlay(
                VStack {
                    Text("Position receipt within frame")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                        .offset(y: -20)
                    
                    Spacer()
                }
            )
    }
    
    private var permissionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.7))
            
            Text("Camera Access Required")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("To scan receipts, please allow camera access in your device settings.")
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Open Settings") {
                openSettings()
            }
            .font(.headline)
            .foregroundColor(.black)
            .padding(.horizontal, 30)
            .padding(.vertical, 12)
            .background(Color.white)
            .cornerRadius(25)
            
            Button("Cancel") {
                dismiss()
            }
            .font(.body)
            .foregroundColor(.white.opacity(0.8))
            .padding(.top, 10)
        }
        .padding()
    }
    
    // MARK: - Actions
    
    private func setupCamera() {
        if cameraService.isAuthorized {
            cameraService.setupCaptureSession()
            cameraService.startSession()
        } else {
            showingPermissionAlert = true
        }
        
        // Monitor for error messages
        if cameraService.errorMessage != nil {
            showingErrorAlert = true
        }
    }
    
    private func capturePhoto() {
        guard !isCapturing else { return }
        
        isCapturing = true
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        Task {
            do {
                let image = try await cameraService.capturePhotoAsync()
                await MainActor.run {
                    capturedImage = image
                    showingImageReview = true
                    isCapturing = false
                }
            } catch {
                await MainActor.run {
                    cameraService.errorMessage = error.localizedDescription
                    showingErrorAlert = true
                    isCapturing = false
                }
            }
        }
    }
    
    private func handleFocusTap(at point: CGPoint) {
        // Convert normalized point to view coordinates
        let viewSize = UIScreen.main.bounds.size
        let focusPoint = CGPoint(
            x: point.x * viewSize.width,
            y: point.y * viewSize.height
        )
        
        // Show focus indicator
        focusLocation = focusPoint
        
        // Set camera focus
        cameraService.setFocusAndExposure(at: point)
        
        // Hide focus indicator after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            focusLocation = nil
        }
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func openSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

#Preview {
    CameraCaptureView { image in
        print("Captured image: \(image)")
    }
}