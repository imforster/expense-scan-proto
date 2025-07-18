import SwiftUI

// MARK: - Primary Button
struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    let isDisabled: Bool
    
    init(title: String, isDisabled: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isDisabled ? Color.gray : AppTheme.primaryColor)
                .foregroundColor(.white)
                .cornerRadius(AppTheme.Dimensions.buttonCornerRadius)
        }
        .disabled(isDisabled)
        .padding(.horizontal, AppTheme.Dimensions.standardPadding)
        .accessibilityLabel(title)
        .accessibilityHint("Tap to \(title.lowercased())")
    }
}

// MARK: - Secondary Button
struct SecondaryButton: View {
    let title: String
    let action: () -> Void
    let isDisabled: Bool
    
    init(title: String, isDisabled: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.clear)
                .foregroundColor(isDisabled ? Color.gray : AppTheme.primaryColor)
                .cornerRadius(AppTheme.Dimensions.buttonCornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Dimensions.buttonCornerRadius)
                        .stroke(isDisabled ? Color.gray : AppTheme.primaryColor, lineWidth: 2)
                )
        }
        .disabled(isDisabled)
        .padding(.horizontal, AppTheme.Dimensions.standardPadding)
        .accessibilityLabel(title)
        .accessibilityHint("Tap to \(title.lowercased())")
    }
}

// MARK: - Card View
struct CardView<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(AppTheme.Dimensions.standardPadding)
            .background(Color.white)
            .cornerRadius(AppTheme.Dimensions.cardCornerRadius)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            .padding(.horizontal, AppTheme.Dimensions.standardPadding)
    }
}

// MARK: - Custom Text Field
struct CustomTextField: View {
    let placeholder: String
    @Binding var text: String
    let keyboardType: UIKeyboardType
    let isSecure: Bool
    
    init(placeholder: String, text: Binding<String>, keyboardType: UIKeyboardType = .default, isSecure: Bool = false) {
        self.placeholder = placeholder
        self._text = text
        self.keyboardType = keyboardType
        self.isSecure = isSecure
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            if isSecure {
                SecureField(placeholder, text: $text)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .keyboardType(keyboardType)
            } else {
                TextField(placeholder, text: $text)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .keyboardType(keyboardType)
            }
        }
        .accessibilityLabel(placeholder)
    }
}

// MARK: - Amount Input Field
struct AmountInputField: View {
    let placeholder: String
    @Binding var amount: String
    
    var body: some View {
        HStack {
            Text("$")
                .font(.headline)
                .foregroundColor(.primary)
            
            TextField(placeholder, text: $amount)
                .keyboardType(.decimalPad)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .accessibilityLabel("\(placeholder) in dollars")
    }
}

// MARK: - Date Picker Field
struct DatePickerField: View {
    let title: String
    @Binding var date: Date
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            DatePicker(
                "",
                selection: $date,
                displayedComponents: [.date]
            )
            .labelsHidden()
            .accessibilityLabel(title)
        }
    }
}

// MARK: - Category Pill
struct CategoryPill: View {
    let category: String
    let color: Color
    
    var body: some View {
        Text(category)
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(20)
            .accessibilityLabel("Category: \(category)")
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: systemImage)
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.gray)
            
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
    }
}

// MARK: - Loading View
struct LoadingView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text(message)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.05))
        .edgesIgnoringSafeArea(.all)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading. \(message)")
    }
}

// MARK: - Error View
struct ErrorView: View {
    let title: String
    let message: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .foregroundColor(AppTheme.errorColor)
            
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Button(action: retryAction) {
                Text("Try Again")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(AppTheme.primaryColor)
                    .cornerRadius(8)
            }
            .padding(.horizontal)
            .padding(.top)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 5)
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(title). \(message)")
    }
}