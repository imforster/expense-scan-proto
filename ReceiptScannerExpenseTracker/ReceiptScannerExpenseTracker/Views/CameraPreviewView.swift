import SwiftUI
import AVFoundation
import UIKit

/// SwiftUI wrapper for AVCaptureVideoPreviewLayer
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    let onTap: ((CGPoint) -> Void)?
    
    init(session: AVCaptureSession, onTap: ((CGPoint) -> Void)? = nil) {
        self.session = session
        self.onTap = onTap
    }
    
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.session = session
        view.onTap = onTap
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.session = session
        uiView.onTap = onTap
    }
}

/// UIView that displays the camera preview
class CameraPreviewUIView: UIView {
    var session: AVCaptureSession? {
        didSet {
            previewLayer.session = session
        }
    }
    
    var onTap: ((CGPoint) -> Void)?
    
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    private var previewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        previewLayer.videoGravity = .resizeAspectFill
        
        // Add tap gesture recognizer for focus/exposure
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tapGesture)
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        let normalizedPoint = CGPoint(
            x: location.x / bounds.width,
            y: location.y / bounds.height
        )
        onTap?(normalizedPoint)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}

/// Focus indicator view that appears when user taps to focus
struct FocusIndicatorView: View {
    @State private var isVisible = false
    @State private var scale: CGFloat = 1.5
    
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .stroke(Color.yellow, lineWidth: 2)
            .frame(width: 80, height: 80)
            .scaleEffect(scale)
            .opacity(isVisible ? 1 : 0)
            .animation(.easeInOut(duration: 0.3), value: isVisible)
            .animation(.easeInOut(duration: 0.3), value: scale)
            .onAppear {
                showFocusIndicator()
            }
    }
    
    private func showFocusIndicator() {
        isVisible = true
        scale = 1.0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isVisible = false
            scale = 1.5
        }
    }
}