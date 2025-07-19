import SwiftUI
import AVFoundation

struct CameraPreviewRepresentable: UIViewRepresentable {
    let cameraService: CameraService
    
    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView(session: cameraService.session ?? AVCaptureSession())
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewView, context: Context) {}
}

struct CameraPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        CameraPreviewRepresentable(cameraService: CameraService())
            .frame(height: 300)
    }
}