import XCTest
import SwiftUI
@testable import ReceiptScannerExpenseTracker

final class OnboardingWelcomeViewTests: XCTestCase {
    
    func testOnboardingPagesContent() {
        // Test that all onboarding pages have required content
        let view = OnboardingWelcomeView(isOnboardingComplete: .constant(false))
        
        // Verify we have the expected number of pages
        XCTAssertEqual(view.pages.count, 5, "Should have 5 onboarding pages")
        
        // Verify first page content
        let firstPage = view.pages[0]
        XCTAssertEqual(firstPage.title, "Welcome to Receipt Scanner")
        XCTAssertEqual(firstPage.subtitle, "Your smart expense tracking companion")
        XCTAssertEqual(firstPage.imageName, "doc.text.viewfinder")
        XCTAssertFalse(firstPage.description.isEmpty)
        
        // Verify all pages have required fields
        for (index, page) in view.pages.enumerated() {
            XCTAssertFalse(page.title.isEmpty, "Page \(index) should have a title")
            XCTAssertFalse(page.subtitle.isEmpty, "Page \(index) should have a subtitle")
            XCTAssertFalse(page.imageName.isEmpty, "Page \(index) should have an image name")
            XCTAssertFalse(page.description.isEmpty, "Page \(index) should have a description")
        }
    }
    
    func testOnboardingPageProgression() {
        // Test the logical flow of onboarding pages
        let view = OnboardingWelcomeView(isOnboardingComplete: .constant(false))
        let pages = view.pages
        
        // Verify the expected sequence of features
        XCTAssertTrue(pages[0].title.contains("Welcome"))
        XCTAssertTrue(pages[1].title.contains("Scanning") || pages[1].title.contains("Receipt"))
        XCTAssertTrue(pages[2].title.contains("Categorization") || pages[2].title.contains("Smart"))
        XCTAssertTrue(pages[3].title.contains("Analytics") || pages[3].title.contains("Powerful"))
        XCTAssertTrue(pages[4].title.contains("Secure") || pages[4].title.contains("Private"))
    }
    
    func testOnboardingPageAccessibilityContent() {
        // Test accessibility features
        let view = OnboardingWelcomeView(isOnboardingComplete: .constant(false))
        
        // Verify each page has proper accessibility content
        for (index, page) in view.pages.enumerated() {
            // Test that accessibility labels would be meaningful
            let expectedAccessibilityContent = "\(page.title). \(page.subtitle). \(page.description)"
            XCTAssertFalse(expectedAccessibilityContent.isEmpty, "Page \(index) should have accessibility content")
            XCTAssertGreaterThan(expectedAccessibilityContent.count, 20, "Page \(index) should have substantial accessibility content")
        }
    }
    
    func testOnboardingPageColors() {
        // Test that each page has distinct colors
        let view = OnboardingWelcomeView(isOnboardingComplete: .constant(false))
        let pages = view.pages
        
        // Verify each page has background and accent colors
        for (index, page) in pages.enumerated() {
            XCTAssertNotNil(page.backgroundColor, "Page \(index) should have a background color")
            XCTAssertNotNil(page.accentColor, "Page \(index) should have an accent color")
        }
        
        // Verify colors are different for visual distinction
        let accentColors = pages.map { $0.accentColor }
        let uniqueColors = Set(accentColors.map { $0.description })
        XCTAssertGreaterThan(uniqueColors.count, 1, "Pages should have different accent colors for visual distinction")
    }
    
    func testOnboardingPageStructure() {
        // Test the OnboardingPage structure
        let page = OnboardingPage(
            title: "Test Title",
            subtitle: "Test Subtitle",
            imageName: "test.icon",
            description: "Test description",
            backgroundColor: Color.blue.opacity(0.1),
            accentColor: Color.blue
        )
        
        XCTAssertEqual(page.title, "Test Title")
        XCTAssertEqual(page.subtitle, "Test Subtitle")
        XCTAssertEqual(page.imageName, "test.icon")
        XCTAssertEqual(page.description, "Test description")
        XCTAssertNotNil(page.backgroundColor)
        XCTAssertNotNil(page.accentColor)
    }
    
    func testOnboardingFeatureHighlights() {
        // Test that key features are highlighted in the onboarding
        let view = OnboardingWelcomeView(isOnboardingComplete: .constant(false))
        let allContent = view.pages.map { "\($0.title) \($0.subtitle) \($0.description)" }.joined(separator: " ")
        
        // Key features that should be mentioned
        let keyFeatures = ["scan", "receipt", "categoriz", "analytic", "report", "secure", "private"]
        
        for feature in keyFeatures {
            XCTAssertTrue(allContent.lowercased().contains(feature), "Onboarding should mention '\(feature)' feature")
        }
    }
}