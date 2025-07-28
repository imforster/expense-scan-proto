import SwiftUI
import Foundation

#if canImport(UIKit)
import UIKit
#endif

/// AppTheme defines the app's visual styling including colors, fonts, and dimensions
struct AppTheme {
    // MARK: - Colors
    static let primaryColor: Color = {
        if let _ = UIColor(named: "PrimaryColor") {
            return Color("PrimaryColor", bundle: nil)
        }
        return defaultPrimaryColor
    }()
    
    static let secondaryColor: Color = {
        if let _ = UIColor(named: "SecondaryColor") {
            return Color("SecondaryColor", bundle: nil)
        }
        return defaultSecondaryColor
    }()
    
    static let accentColor: Color = {
        if let _ = UIColor(named: "AccentColor") {
            return Color("AccentColor", bundle: nil)
        }
        return defaultAccentColor
    }()
    
    static let backgroundColor: Color = {
        #if canImport(UIKit)
        if let _ = UIColor(named: "BackgroundColor") {
            return Color("BackgroundColor", bundle: nil)
        }
        return Color(UIColor.systemBackground)
        #else
        return Color.white
        #endif
    }()
    
    static let errorColor: Color = {
        #if canImport(UIKit)
        if let _ = UIColor(named: "ErrorColor") {
            return Color("ErrorColor", bundle: nil)
        }
        #endif
        return defaultErrorColor
    }()
    
    // Additional adaptive colors for better theme support
    #if canImport(UIKit)
    static let cardBackgroundColor = Color(UIColor.secondarySystemBackground)
    static let groupedBackgroundColor = Color(UIColor.systemGroupedBackground)
    static let separatorColor = Color(UIColor.separator)
    static let labelColor = Color(UIColor.label)
    static let secondaryLabelColor = Color(UIColor.secondaryLabel)
    static let tertiaryLabelColor = Color(UIColor.tertiaryLabel)

    
    // Default colors as fallbacks
    static let defaultPrimaryColor = Color.blue
    static let defaultSecondaryColor = Color.green
    static let defaultAccentColor = Color.orange
    static let defaultErrorColor = Color.red
    
    // MARK: - Typography
    struct Typography {
        static let titleFont = Font.system(.largeTitle, design: .rounded).weight(.bold)
        static let headingFont = Font.system(.title, design: .rounded).weight(.semibold)
        static let subheadingFont = Font.system(.title3, design: .rounded).weight(.medium)
        static let bodyFont = Font.system(.body)
        static let captionFont = Font.system(.caption)
        
        // Accessibility scaling support
        static func scaledFont(_ font: Font, sizeCategory: ContentSizeCategory) -> Font {
            switch sizeCategory {
            case .accessibilityExtraExtraExtraLarge, .accessibilityExtraExtraLarge, .accessibilityExtraLarge:
                return font.weight(.bold)
            default:
                return font
            }
        }
    }
    
    // MARK: - Dimensions
    struct Dimensions {
        static let standardPadding: CGFloat = 16
        static let smallPadding: CGFloat = 8
        static let largePadding: CGFloat = 24
        
        static let buttonHeight: CGFloat = 50
        static let buttonCornerRadius: CGFloat = 10
        
        static let cardCornerRadius: CGFloat = 12
        
        // Accessibility scaling
        static func scaledDimension(_ dimension: CGFloat, sizeCategory: ContentSizeCategory) -> CGFloat {
            switch sizeCategory {
            case .accessibilityExtraExtraExtraLarge:
                return dimension * 1.5
            case .accessibilityExtraExtraLarge:
                return dimension * 1.4
            case .accessibilityExtraLarge:
                return dimension * 1.3
            case .accessibilityLarge:
                return dimension * 1.2
            case .accessibilityMedium:
                return dimension * 1.1
            default:
                return dimension
            }
        }
    }
    
    // MARK: - Animation
    struct Animation {
        static let standardDuration: Double = 0.3
        static let slowDuration: Double = 0.5
        
        static let standardCurve = SwiftUI.Animation.easeInOut(duration: standardDuration)
        static let slowCurve = SwiftUI.Animation.easeInOut(duration: slowDuration)
        
        // Reduced motion support
        static func preferredAnimation(isReducedMotion: Bool) -> SwiftUI.Animation? {
            return isReducedMotion ? nil : standardCurve
        }
    }
}

// MARK: - View Extensions
extension View {
    func primaryButtonStyle() -> some View {
        self
            .frame(height: AppTheme.Dimensions.buttonHeight)
            .frame(maxWidth: .infinity)
            .background(AppTheme.primaryColor)
            .foregroundColor(.white)
            .cornerRadius(AppTheme.Dimensions.buttonCornerRadius)
            .padding(.horizontal, AppTheme.Dimensions.standardPadding)
    }
    
    func secondaryButtonStyle() -> some View {
        self
            .frame(height: AppTheme.Dimensions.buttonHeight)
            .frame(maxWidth: .infinity)
            .background(Color.clear)
            .foregroundColor(AppTheme.primaryColor)
            .cornerRadius(AppTheme.Dimensions.buttonCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Dimensions.buttonCornerRadius)
                    .stroke(AppTheme.primaryColor, lineWidth: 2)
            )
            .padding(.horizontal, AppTheme.Dimensions.standardPadding)
    }
    
    func cardStyle() -> some View {
        self
            .padding(AppTheme.Dimensions.standardPadding)
            .background(AppTheme.cardBackgroundColor)
            .cornerRadius(AppTheme.Dimensions.cardCornerRadius)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            .padding(.horizontal, AppTheme.Dimensions.standardPadding)
    }
    
    // Accessibility modifiers
    func accessibleButton(label: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isButton)
    }
    
    func accessibleImage(label: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isImage)
    }
    
    func accessibleText(label: String? = nil) -> some View {
        self.accessibilityLabel(label ?? "")
    }
}
