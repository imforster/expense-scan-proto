import SwiftUI

/// AppTheme defines the app's visual styling including colors, fonts, and dimensions
struct AppTheme {
    // MARK: - Adaptive Colors
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
        if let _ = UIColor(named: "BackgroundColor") {
            return Color("BackgroundColor", bundle: nil)
        }
        return defaultBackgroundColor
    }()
    
    static let errorColor: Color = {
        if let _ = UIColor(named: "ErrorColor") {
            return Color("ErrorColor", bundle: nil)
        }
        return defaultErrorColor
    }()
    
    // Default adaptive colors - automatically adjust for light/dark mode
    static let defaultPrimaryColor = Color.blue
    static let defaultSecondaryColor = Color.green
    static let defaultAccentColor = Color.orange
    static let defaultBackgroundColor = Color(.systemBackground)
    static let defaultErrorColor = Color.red
    
    // MARK: - Semantic Colors
    /// Colors that adapt to the current theme
    struct Colors {
        static let primary = AppTheme.primaryColor
        static let secondary = AppTheme.secondaryColor
        static let accent = AppTheme.accentColor
        static let background = AppTheme.backgroundColor
        static let error = AppTheme.errorColor
        
        // System adaptive colors
        static let systemBackground = Color(.systemBackground)
        static let secondarySystemBackground = Color(.secondarySystemBackground)
        static let tertiarySystemBackground = Color(.tertiarySystemBackground)
        
        static let label = Color(.label)
        static let secondaryLabel = Color(.secondaryLabel)
        static let tertiaryLabel = Color(.tertiaryLabel)
        
        static let systemGray = Color(.systemGray)
        static let systemGray2 = Color(.systemGray2)
        static let systemGray3 = Color(.systemGray3)
        static let systemGray4 = Color(.systemGray4)
        static let systemGray5 = Color(.systemGray5)
        static let systemGray6 = Color(.systemGray6)
        
        // Theme-aware custom colors
        static let cardBackground = Color(.secondarySystemBackground)
        static let separatorColor = Color(.separator)
        static let buttonBackground = primary
        static let buttonForeground = Color(.systemBackground)
    }
    
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
            .background(AppTheme.Colors.buttonBackground)
            .foregroundColor(AppTheme.Colors.buttonForeground)
            .cornerRadius(AppTheme.Dimensions.buttonCornerRadius)
            .padding(.horizontal, AppTheme.Dimensions.standardPadding)
    }
    
    func secondaryButtonStyle() -> some View {
        self
            .frame(height: AppTheme.Dimensions.buttonHeight)
            .frame(maxWidth: .infinity)
            .background(Color.clear)
            .foregroundColor(AppTheme.Colors.primary)
            .cornerRadius(AppTheme.Dimensions.buttonCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Dimensions.buttonCornerRadius)
                    .stroke(AppTheme.Colors.primary, lineWidth: 2)
            )
            .padding(.horizontal, AppTheme.Dimensions.standardPadding)
    }
    
    func cardStyle() -> some View {
        self
            .padding(AppTheme.Dimensions.standardPadding)
            .background(AppTheme.Colors.cardBackground)
            .cornerRadius(AppTheme.Dimensions.cardCornerRadius)
            .shadow(color: AppTheme.Colors.systemGray4.opacity(0.3), radius: 5, x: 0, y: 2)
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
