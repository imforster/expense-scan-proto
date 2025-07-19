import SwiftUI
import Combine
import AVFoundation

struct ScanView: View {
    // MARK: - Properties
    @StateObject private var viewModel = ScanViewModel()
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                // Main content
                VStack {
                    if viewModel.showPermissionView {
                        permissionView
                    } else if viewModel.showCaptureView {
                        cameraView
                    } else if viewModel.showReviewView {
                        reviewView
                    } else {
                        initialView
                    }
                }
                
                // Loading overlay
                if viewModel.isLoading {
                    LoadingView(message: "Processing...")
                }
                
                // Error overlay
                if let error = viewModel.error {
                    errorView(error: error)
                }
            }
            .navigationTitle("Scan Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if viewModel.showReviewView {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Retake") {
                            viewModel.retakePhoto()
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Use Photo") {
                            viewModel.usePhoto()
                        }
                    }
                }
            }
            .onAppear {
                viewModel.checkPermissions()
            }
            .onDisappear {
                viewModel.stopSession()
            }
        }
    }
    
    // MARK: - Subviews
    private var initialView: some View {
        VStack {
            Spacer()
            
            Image(systemName: "camera.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .foregroundColor(AppTheme.primaryColor)
                .padding()
            
            Text("Scan a Receipt")
                .font(AppTheme.Typography.headingFont)
                .padding(.bottom, 8)
            
            Text("Take a photo of your receipt to automatically extract information")
                .font(AppTheme.Typography.bodyFont)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Spacer()
            
            PrimaryButton(title: "Start Scanning") {
                viewModel.startScanning()
            }
            .padding(.bottom)
        }
        .padding()
    }
    
    private var permissionView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "camera.metering.none")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(.gray)
            
            Text("Camera Access Required")
                .font(AppTheme.Typography.headingFont)
            
            Text("This app needs camera access to scan receipts. Please grant access in your device settings.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Spacer()
            
            PrimaryButton(title: "Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .padding(.bottom)
        }
        .padding()
    }
    
    private var cameraView: some View {
        ZStack {
            // Camera preview
            CameraPreviewRepresentable(cameraService: viewModel.cameraService)
                .edgesIgnoringSafeArea(.all)
            
            // Overlay for receipt guidance
            VStack {
                Spacer()
                
                // Capture button
                Button(action: {
                    viewModel.capturePhoto()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 70, height: 70)
                        
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                            .frame(width: 80, height: 80)
                    }
                }
                .padding(.bottom, 30)
                .accessibilityLabel("Take photo")
            }
        }
    }
    
    private var reviewView: some View {
        VStack {
            if let capturedImage = viewModel.capturedImage {
                Image(uiImage: capturedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            }
            
            HStack(spacing: 20) {
                SecondaryButton(title: "Retake") {
                    viewModel.retakePhoto()
                }
                
                PrimaryButton(title: "Use Photo") {
                    viewModel.usePhoto()
                }
            }
            .padding()
        }
    }
    
    private func errorView(error: String) -> some View {
        ErrorView(
            title: "Error",
            message: error,
            retryAction: {
                viewModel.dismissError()
            }
        )
    }
}

// MARK: - ViewModel
class ScanViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var showPermissionView = false
    @Published var showCaptureView = false
    @Published var showReviewView = false
    @Published var capturedImage: UIImage?
    @Published var capturedImageURL: URL?
    @Published var isLoading = false
    @Published var error: String?
    
    // MARK: - Properties
    let cameraService = CameraService()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {}
    
    // MARK: - Methods
    func checkPermissions() {
        cameraService.checkPermissions()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure = completion {
                        self?.showPermissionView = true
                    }
                },
                receiveValue: { [weak self] granted in
                    if granted {
                        self?.showPermissionView = false
                    } else {
                        self?.showPermissionView = true
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func startScanning() {
        isLoading = true
        
        cameraService.setupAndStartCaptureSession()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    
                    if case .failure(let error) = completion {
                        self?.handleError(error)
                    }
                },
                receiveValue: { [weak self] success in
                    self?.isLoading = false
                    
                    if success {
                        self?.showCaptureView = true
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func capturePhoto() {
        isLoading = true
        
        cameraService.capturePhoto()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    
                    if case .failure(let error) = completion {
                        self?.handleError(error)
                    }
                },
                receiveValue: { [weak self] image in
                    self?.isLoading = false
                    self?.capturedImage = image
                    self?.capturedImageURL = self?.cameraService.saveImageToTemporaryStorage(image)
                    self?.showCaptureView = false
                    self?.showReviewView = true
                }
            )
            .store(in: &cancellables)
    }
    
    func retakePhoto() {
        capturedImage = nil
        capturedImageURL = nil
        showReviewView = false
        showCaptureView = true
        cameraService.startSession()
    }
    
    func usePhoto() {
        // This will be implemented in task 2.2 for image processing
        // For now, we'll just print the URL of the saved image
        if let url = capturedImageURL {
            print("Image saved at: \(url)")
            // Here we would normally proceed to the next step in the flow
        }
    }
    
    func stopSession() {
        cameraService.stopSession()
    }
    
    func dismissError() {
        error = nil
    }
    
    private func handleError(_ error: Error) {
        let errorMessage: String
        
        if let cameraError = error as? CameraService.CameraError {
            switch cameraError {
            case .cameraUnavailable:
                errorMessage = "Camera is unavailable on this device."
            case .deniedAuthorization, .restrictedAuthorization:
                errorMessage = "Camera access is denied. Please enable it in Settings."
            case .unknownAuthorization:
                errorMessage = "Unknown authorization status for camera access."
            case .cannotAddInput, .cannotAddOutput, .createCaptureInput:
                errorMessage = "Failed to configure camera."
            case .photoProcessingFailed:
                errorMessage = "Failed to process the photo."
            case .captureError:
                errorMessage = "Failed to capture photo."
            case .noImageData:
                errorMessage = "No image data available."
            }
        } else {
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
        }
        
        self.error = errorMessage
    }
}

struct ScanView_Previews: PreviewProvider {
    static var previews: some View {
        ScanView()
    }
}