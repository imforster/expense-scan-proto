import SwiftUI
import AVFoundation
import Photos
import UserNotifications

struct PermissionRequestView: View {
    @State private var currentPermission = 0
    @Binding var isPermissionFlowComplete: Bool
    @State private var cameraPermissionStatus: AVAuthorizationStatus = .notDetermined
    @State private var photoLibraryPermissionStatus: PHAuthorizationStatus = .notDetermined
    @State private var notificationPermissionStatus: UNAuthorizationStatus = .notDetermined
    
    private let permissions = [
        PermissionInfo(
            title: "Camera Access",
            description: "We need camera access to scan your receipts and extract expense information automatically.",
            iconName: "camera.fill",
            type: .camera
        ),
        PermissionInfo(
            title: "Photo Library",
            description: "Access your photo library to import existing receipt images for processing.",
            iconName: "photo.on.rectangle",
            type: .photoLibrary
        ),
        PermissionInfo(
            title: "Notifications",
            description: "Get notified when you're approaching budget limits or need to review expenses.",
            iconName: "bell.fill",
            type: .notifications
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                Text("Permissions Required")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("To provide the best experience, we need access to a few features on your device.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(.top, 40)
            .padding(.bottom, 30)
            
            // Permission cards
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(0..<permissions.count, id: \.self) { index in
                        PermissionCard(
                            permission: permissions[index],
                            isGranted: isPermissionGranted(for: permissions[index].type),
                            onRequest: { requestPermission(for: permissions[index].type) }
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
            
            Spacer()
            
            // Continue button
            VStack(spacing: 12) {
                Button("Continue") {
                    NotificationCenter.default.post(
                        name: .onboardingStepCompleted,
                        object: OnboardingStep.permissions
                    )
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                
                Button("Skip for Now") {
                    isPermissionFlowComplete = true
                }
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 50)
        }
        .onAppear {
            checkPermissionStatuses()
        }
    }
    
    private func isPermissionGranted(for type: PermissionType) -> Bool {
        switch type {
        case .camera:
            return cameraPermissionStatus == .authorized
        case .photoLibrary:
            return photoLibraryPermissionStatus == .authorized || photoLibraryPermissionStatus == .limited
        case .notifications:
            return notificationPermissionStatus == .authorized
        }
    }
    
    private func checkPermissionStatuses() {
        cameraPermissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
        photoLibraryPermissionStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationPermissionStatus = settings.authorizationStatus
            }
        }
    }
    
    private func requestPermission(for type: PermissionType) {
        switch type {
        case .camera:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    cameraPermissionStatus = granted ? .authorized : .denied
                }
            }
        case .photoLibrary:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                DispatchQueue.main.async {
                    photoLibraryPermissionStatus = status
                }
            }
        case .notifications:
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                DispatchQueue.main.async {
                    notificationPermissionStatus = granted ? .authorized : .denied
                }
            }
        }
    }
}

struct PermissionInfo {
    let title: String
    let description: String
    let iconName: String
    let type: PermissionType
}

enum PermissionType {
    case camera, photoLibrary, notifications
}

struct PermissionCard: View {
    let permission: PermissionInfo
    let isGranted: Bool
    let onRequest: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: permission.iconName)
                    .font(.title2)
                    .foregroundColor(.accentColor)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(permission.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(permission.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                if isGranted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                } else {
                    Button("Allow") {
                        onRequest()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(16)
        .background(AppTheme.systemGray6Color)
        .cornerRadius(12)
    }
}