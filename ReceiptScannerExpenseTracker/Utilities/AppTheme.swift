import SwiftUI

/// AppTheme defines the app's visual styling including colors, fonts, and dimensions
struct AppTheme {
    // MARK: - Colors
    static let primaryColor = Color("PrimaryColor", bundle: nil)
    static let secondaryColor = Color("SecondaryColor", bundle: nil)
    static let accentColor = Color("AccentColor", bundle: nil)
    static let backgroundColor = Color("BackgroundColor", bundle: nil)
    static let errorColor = Color("ErrorColor", bundle: nil)
    
    // Default colors until we create the assets
    static let defaultPrimaryColor = Color.blue
    static let defaultSecondaryColor = Color.green
    static let defaultAccentColor = Color.orange
    static let defaultBackgroundColor = Color.white
    static let defaultErrorColor = Color.red
    
    // MARK: - Typography
    struct Typography {
        static let titleFont = Font.system(.largeTitle, design: .rounded).weight(.bold)
        static let headingFont = Font.system(.title, design: .rounded).weight(.semibold)
        static let subheadingFont = Font.system(.title3, design: .rounded).weight(.medium)
        static let bodyFont = Font.system(.body)
        static let captionFont = Font.system(.caption)
    }
    
    // MARK: - Dimensions
    struct Dimensions {
        static let standardPadding: CGFloat = 16
        static let smallPadding: CGFloat = 8
        static let largePadding: CGFloat = 24
        
        static let buttonHeight: CGFloat = 50
        static let buttonCornerRadius: CGFloat = 10
        
        static let cardCornerRadius: CGFloat = 12
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
            .background(Color.white)
            .cornerRadius(AppTheme.Dimensions.cardCornerRadius)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            .padding(.horizontal, AppTheme.Dimensions.standardPadding)
    }
}