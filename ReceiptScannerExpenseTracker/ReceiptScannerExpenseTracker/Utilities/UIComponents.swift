import SwiftUI
import UIKit

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
        .accessibilityAddTraits(.isButton)
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
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Icon Button
struct IconButton: View {
    let systemName: String
    let label: String
    let action: () -> Void
    let isDisabled: Bool
    
    init(systemName: String, label: String, isDisabled: Bool = false, action: @escaping () -> Void) {
        self.systemName = systemName
        self.label = label
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 22))
                .foregroundColor(isDisabled ? Color.gray : AppTheme.primaryColor)
                .padding()
                .background(Color.white)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
        }
        .disabled(isDisabled)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
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
    let errorMessage: String?
    
    init(
        placeholder: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType = .default,
        isSecure: Bool = false,
        errorMessage: String? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self.keyboardType = keyboardType
        self.isSecure = isSecure
        self.errorMessage = errorMessage
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if isSecure {
                SecureField(placeholder, text: $text)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .keyboardType(keyboardType)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(errorMessage != nil ? AppTheme.errorColor : Color.clear, lineWidth: 1)
                    )
            } else {
                TextField(placeholder, text: $text)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .keyboardType(keyboardType)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(errorMessage != nil ? AppTheme.errorColor : Color.clear, lineWidth: 1)
                    )
            }
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(AppTheme.errorColor)
                    .padding(.leading, 4)
                    .accessibilityLabel("Error: \(errorMessage)")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(placeholder)
        .accessibilityHint(errorMessage != nil ? "Error: \(errorMessage!)" : "")
    }
}

// MARK: - Amount Input Field
struct AmountInputField: View {
    let placeholder: String
    @Binding var amount: String
    let errorMessage: String?
    
    init(placeholder: String, amount: Binding<String>, errorMessage: String? = nil) {
        self.placeholder = placeholder
        self._amount = amount
        self.errorMessage = errorMessage
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
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
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(errorMessage != nil ? AppTheme.errorColor : Color.clear, lineWidth: 1)
            )
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(AppTheme.errorColor)
                    .padding(.leading, 4)
                    .accessibilityLabel("Error: \(errorMessage)")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(placeholder) in dollars")
        .accessibilityHint(errorMessage != nil ? "Error: \(errorMessage!)" : "")
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
            .accessibilityHint("Double tap to select a date")
        }
    }
}

// MARK: - Category Pill
struct CategoryPill: View {
    let category: String
    let color: Color
    let isSelected: Bool
    let action: (() -> Void)?
    
    init(category: String, color: Color, isSelected: Bool = false, action: (() -> Void)? = nil) {
        self.category = category
        self.color = color
        self.isSelected = isSelected
        self.action = action
    }
    
    var body: some View {
        Button(action: { action?() }) {
            Text(category)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? color : color.opacity(0.2))
                .foregroundColor(isSelected ? .white : color)
                .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Category: \(category)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
        .accessibilityHint(isSelected ? "Selected" : "Tap to select")
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(
        title: String,
        message: String,
        systemImage: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: systemImage)
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.gray)
                .accessibleImage(label: "")
            
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(AppTheme.primaryColor)
                        .cornerRadius(8)
                }
                .padding(.horizontal)
                .padding(.top)
                .accessibilityLabel(actionTitle)
            }
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
        .accessibilityAddTraits(.updatesFrequently)
    }
}

// MARK: - Progress Loading View
struct ProgressLoadingView: View {
    let message: String
    let progress: Float
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle())
                .frame(width: 200)
            
            Text(message)
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("\(Int(progress * 100))%")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(30)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 5)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.2))
        .edgesIgnoringSafeArea(.all)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Processing. \(message). \(Int(progress * 100)) percent complete")
        .accessibilityValue("\(Int(progress * 100)) percent")
        .accessibilityAddTraits(.updatesFrequently)
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
                .accessibleImage(label: "Error")
            
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
            .accessibilityLabel("Try Again")
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

// MARK: - Receipt Card
struct ReceiptCard: View {
    let merchantName: String
    let date: Date
    let amount: String
    let imageURL: URL?
    let onTap: () -> Void
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                if let imageURL = imageURL {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 60, height: 80)
                                .cornerRadius(8)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 80)
                                .cornerRadius(8)
                                .clipped()
                        case .failure:
                            Image(systemName: "doc.text.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 30, height: 30)
                                .frame(width: 60, height: 80)
                                .background(Color.gray.opacity(0.3))
                                .cornerRadius(8)
                        @unknown default:
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 60, height: 80)
                                .cornerRadius(8)
                        }
                    }
                } else {
                    Image(systemName: "doc.text.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                        .frame(width: 60, height: 80)
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(merchantName)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(dateFormatter.string(from: date))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("$\(amount)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.primaryColor)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Receipt from \(merchantName) on \(dateFormatter.string(from: date)) for $\(amount)")
        .accessibilityHint("Tap to view details")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Expense Summary Card
struct ExpenseSummaryCard: View {
    let title: String
    let amount: String
    let trend: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("$\(amount)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            HStack(spacing: 4) {
                Image(systemName: trend >= 0 ? "arrow.up" : "arrow.down")
                    .font(.caption)
                    .foregroundColor(trend >= 0 ? .red : .green)
                
                Text("\(abs(trend), specifier: "%.1f")%")
                    .font(.caption)
                    .foregroundColor(trend >= 0 ? .red : .green)
                
                Text("vs last month")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): $\(amount), \(trend >= 0 ? "up" : "down") \(abs(trend), specifier: "%.1f") percent compared to last month")
    }
}