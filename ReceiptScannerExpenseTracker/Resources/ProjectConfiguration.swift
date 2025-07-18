import Foundation

/// ProjectConfiguration defines the app's configuration settings and capabilities
struct ProjectConfiguration {
    // MARK: - App Information
    static let appName = "Receipt Scanner Expense Tracker"
    static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    static let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    
    // MARK: - Feature Flags
    static let enableCloudSync = true
    static let enableBiometricAuthentication = true
    static let enableOfflineMode = true
    static let enableAnalytics = true
    
    // MARK: - App Settings
    static let minimumIOSVersion = "15.0"
    static let defaultCurrency = "USD"
    static let defaultLanguage = "en"
    static let maxImageSize = 10 * 1024 * 1024 // 10MB
    
    // MARK: - Security Settings
    static let securityTimeout = 5 * 60 // 5 minutes
    static let maxLoginAttempts = 5
    static let passwordMinLength = 8
    
    // MARK: - Storage Settings
    static let maxLocalStorageSize = 500 * 1024 * 1024 // 500MB
    static let cacheTTL = 7 * 24 * 60 * 60 // 7 days
    
    // MARK: - Camera Settings
    static let preferredCameraResolution = "high" // low, medium, high
    static let saveOriginalImages = true
    
    // MARK: - OCR Settings
    static let ocrConfidenceThreshold = 0.7 // 70% confidence
    static let ocrLanguage = "en-US"
    
    // MARK: - Reporting Settings
    static let defaultReportPeriod = "month" // day, week, month, year
    static let maxReportPeriod = "year"
    
    // MARK: - Capabilities
    static let capabilities = [
        "camera_access",
        "photo_library_access",
        "face_id",
        "cloud_sync",
        "offline_mode",
        "export_data",
        "import_data",
        "backup_restore"
    ]
}