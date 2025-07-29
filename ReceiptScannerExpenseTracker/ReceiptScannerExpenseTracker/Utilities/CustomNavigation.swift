import SwiftUI

// MARK: - Custom Tab Bar
struct CustomTabBar: View {
    @Binding var selectedTab: Int
    let items: [TabItem]
    
    struct TabItem {
        let icon: String
        let label: String
        let accessibilityLabel: String
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<items.count, id: \.self) { index in
                Button(action: {
                    withAnimation {
                        selectedTab = index
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: items[index].icon)
                            .font(.system(size: 22))
                            .foregroundColor(selectedTab == index ? AppTheme.primaryColor : .gray)
                        
                        Text(items[index].label)
                            .font(.caption2)
                            .foregroundColor(selectedTab == index ? AppTheme.primaryColor : .gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        selectedTab == index ?
                            AppTheme.primaryColor.opacity(0.1) :
                            Color.clear
                    )
                    .cornerRadius(8)
                }
                .accessibilityLabel(items[index].accessibilityLabel)
                .accessibilityAddTraits(selectedTab == index ? [.isButton, .isSelected] : [.isButton])
                .accessibilityHint(selectedTab == index ? "Selected" : "Tap to select")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color(.systemGray4).opacity(0.3), radius: 5, x: 0, y: -2)
    }
}

// MARK: - Custom Navigation Bar
struct CustomNavigationBar<TrailingContent: View>: View {
    let title: String
    let showBackButton: Bool
    let backAction: () -> Void
    let trailingContent: TrailingContent
    
    init(
        title: String,
        showBackButton: Bool = true,
        backAction: @escaping () -> Void = {},
        @ViewBuilder trailingContent: @escaping () -> TrailingContent
    ) {
        self.title = title
        self.showBackButton = showBackButton
        self.backAction = backAction
        self.trailingContent = trailingContent()
    }
    
    var body: some View {
        HStack {
            if showBackButton {
                Button(action: backAction) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppTheme.primaryColor)
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                        .shadow(color: Color(.systemGray4).opacity(0.3), radius: 2)
                }
                .accessibilityLabel("Back")
                .accessibilityHint("Go back to previous screen")
            }
            
            Spacer()
            
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .accessibilityAddTraits(.isHeader)
            
            Spacer()
            
            trailingContent
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(color: Color(.systemGray4).opacity(0.2), radius: 5, x: 0, y: 2)
    }
}

// Convenience initializer without trailing content
extension CustomNavigationBar where TrailingContent == EmptyView {
    init(title: String, showBackButton: Bool = true, backAction: @escaping () -> Void = {}) {
        self.init(title: title, showBackButton: showBackButton, backAction: backAction) {
            EmptyView()
        }
    }
}

// MARK: - Segmented Control
struct CustomSegmentedControl: View {
    @Binding var selection: Int
    let options: [String]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<options.count, id: \.self) { index in
                Button(action: {
                    withAnimation {
                        selection = index
                    }
                }) {
                    Text(options[index])
                        .font(.subheadline)
                        .fontWeight(selection == index ? .semibold : .regular)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity)
                        .background(selection == index ? AppTheme.primaryColor : Color.clear)
                        .foregroundColor(selection == index ? Color(.systemBackground) : .primary)
                }
                .accessibilityLabel(options[index])
                .accessibilityAddTraits(selection == index ? [.isButton, .isSelected] : [.isButton])
                .accessibilityHint(selection == index ? "Selected" : "Tap to select")
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

// MARK: - Filter Bar
struct FilterBar: View {
    @Binding var selectedFilter: String
    let filters: [String]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(filters, id: \.self) { filter in
                    Button(action: {
                        withAnimation {
                            selectedFilter = filter
                        }
                    }) {
                        Text(filter)
                            .font(.subheadline)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(selectedFilter == filter ? AppTheme.primaryColor : Color(.systemGray6))
                            .foregroundColor(selectedFilter == filter ? Color(.systemBackground) : .primary)
                            .cornerRadius(20)
                    }
                    .accessibilityLabel(filter)
                    .accessibilityAddTraits(selectedFilter == filter ? [.isButton, .isSelected] : [.isButton])
                    .accessibilityHint(selectedFilter == filter ? "Selected" : "Tap to select")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Search Bar
struct SearchBar: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField(placeholder, text: $text)
                .foregroundColor(.primary)
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(placeholder)
    }
}

// MARK: - Modal Presentation
struct ModalView<Content: View>: View {
    @Binding var isPresented: Bool
    let title: String
    let content: Content
    
    init(isPresented: Binding<Bool>, title: String, @ViewBuilder content: () -> Content) {
        self._isPresented = isPresented
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    withAnimation {
                        isPresented = false
                    }
                }
            
            VStack(spacing: 0) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .accessibilityAddTraits(.isHeader)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation {
                            isPresented = false
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Close")
                }
                .padding()
                .background(Color(.systemBackground))
                
                Divider()
                
                content
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemBackground))
            }
            .cornerRadius(16)
            .padding()
            .transition(.move(edge: .bottom))
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Bottom Sheet
struct BottomSheet<Content: View>: View {
    @Binding var isPresented: Bool
    let content: Content
    let showHandle: Bool
    
    init(isPresented: Binding<Bool>, showHandle: Bool = true, @ViewBuilder content: () -> Content) {
        self._isPresented = isPresented
        self.showHandle = showHandle
        self.content = content()
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            if isPresented {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        withAnimation {
                            isPresented = false
                        }
                    }
                    .transition(.opacity)
                
                VStack(spacing: 0) {
                    if showHandle {
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(Color.gray.opacity(0.5))
                            .frame(width: 40, height: 5)
                            .padding(.top, 8)
                            .padding(.bottom, 8)
                    }
                    
                    content
                        .frame(maxWidth: .infinity)
                }
                .background(Color(.systemBackground))
                .cornerRadius(16, corners: [.topLeft, .topRight])
                .transition(.move(edge: .bottom))
            }
        }
        .edgesIgnoringSafeArea(.bottom)
        .animation(.spring(), value: isPresented)
    }
}

// Helper extension for rounded corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}