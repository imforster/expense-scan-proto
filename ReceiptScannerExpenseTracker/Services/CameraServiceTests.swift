import XCTest
import Combine
@testable import ReceiptScannerExpenseTracker

class CameraServiceTests: XCTestCase {
    var cameraService: CameraService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        cameraService = CameraService()
        cancellables = []
    }
    
    override func tearDown() {
        cameraService = nil
        cancellables = nil
        super.tearDown()
    }
    
    func testSaveImageToTemporaryStorage() {
        // Create a test image
        let size = CGSize(width: 100, height: 100)
        UIGraphicsBeginImageContext(size)
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(UIColor.red.cgColor)
        context?.fill(CGRect(origin: .zero, size: size))
        let testImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        // Test saving to temporary storage
        let url = cameraService.saveImageToTemporaryStorage(testImage)
        
        // Verify the URL is not nil and file exists
        XCTAssertNotNil(url, "URL should not be nil")
        if let url = url {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "File should exist at the returned URL")
        }
    }
    
    // Note: Most camera functionality requires a real device and cannot be easily unit tested
    // For a real project, we would use UI tests on actual devices to test the camera functionality
}