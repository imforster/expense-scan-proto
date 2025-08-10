//
//  ContentView.swift
//  ReceiptScannerExpenseTracker
//
//  Created by Ian Forster (Home) on 2025-07-18.
//

import CoreData
import SwiftUI

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedTab = 0
    @State private var showingCameraView = false
    @StateObject private var expenseViewModel: ExpenseListViewModel

    init() {
        let dataService = ExpenseDataService(context: CoreDataManager.shared.viewContext)
        self._expenseViewModel = StateObject(wrappedValue: ExpenseListViewModel(dataService: dataService))
    }

    private let tabItems = [
        CustomTabBar.TabItem(
            icon: "house.fill",
            label: "Home",
            accessibilityLabel: "Home tab"
        ),
        CustomTabBar.TabItem(
            icon: "camera.fill",
            label: "Scan",
            accessibilityLabel: "Scan receipt tab"
        ),
        CustomTabBar.TabItem(
            icon: "list.bullet",
            label: "Expenses",
            accessibilityLabel: "Expenses list tab"
        ),
        CustomTabBar.TabItem(
            icon: "chart.pie.fill",
            label: "Reports",
            accessibilityLabel: "Reports tab"
        ),
        CustomTabBar.TabItem(
            icon: "gearshape.fill",
            label: "Settings",
            accessibilityLabel: "Settings tab"
        ),
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                homeView
                    .tag(0)

                scanPlaceholderView
                    .tag(1)

                expensesPlaceholderView
                    .tag(2)

                reportsPlaceholderView
                    .tag(3)

                settingsPlaceholderView
                    .tag(4)
            }
            .edgesIgnoringSafeArea(.bottom)
            .opacity(showingCameraView ? 0 : 1)
            .animation(reduceMotion ? .none : .easeInOut(duration: 0.3), value: showingCameraView)

            if !showingCameraView {
                CustomTabBar(selectedTab: $selectedTab, items: tabItems)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(AppTheme.backgroundColor)
        .animation(reduceMotion ? .none : .easeInOut, value: selectedTab)
        .onAppear {
            Task {
                await expenseViewModel.loadExpenses()
            }
        }
        .onChange(of: selectedTab) { newTab in
            // Refresh data when returning to home tab
            if newTab == 0 {
                Task {
                    await expenseViewModel.refreshExpenses()
                }
            }
        }
    }

    // MARK: - Summary Cards View
    
    private var summaryCardsView: some View {
        Group {
            if expenseViewModel.isLoading {
                // Loading state for summary cards
                HStack(spacing: 12) {
                    ForEach(0..<2, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                            .frame(height: 100)
                            .redacted(reason: .placeholder)
                            .shimmerEffect()
                    }
                }
                .padding(.horizontal)
            } else {
                let summaryData = expenseViewModel.summaryData
                
                // Always show at least two cards - use real data when available, fallback to zero amounts
                HStack(spacing: 12) {
                    // First card - This Month
                    if let monthData = summaryData.first(where: { $0.title == "This Month" }) {
                        ExpenseSummaryCard(
                            summaryData: monthData,
                            color: AppTheme.primaryColor
                        )
                    } else {
                        ExpenseSummaryCard(
                            summaryData: SummaryData(title: "This Month", amount: expenseViewModel.currentMonthTotal),
                            color: AppTheme.primaryColor
                        )
                    }
                    
                    // Second card - This Week
                    if let weekData = summaryData.first(where: { $0.title == "This Week" }) {
                        ExpenseSummaryCard(
                            summaryData: weekData,
                            color: AppTheme.secondaryColor
                        )
                    } else {
                        ExpenseSummaryCard(
                            summaryData: SummaryData(title: "This Week", amount: expenseViewModel.currentWeekTotal),
                            color: AppTheme.secondaryColor
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
        .animation(reduceMotion ? .none : .easeInOut(duration: 0.3), value: expenseViewModel.isLoading)
        .animation(reduceMotion ? .none : .easeInOut(duration: 0.3), value: expenseViewModel.summaryData.count)
    }

    // MARK: - Helper Methods
    
    private func formatAmount(_ amount: NSDecimalNumber?) -> String {
        guard let amount = amount else { return "0.00" }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        
        return formatter.string(from: amount) ?? "0.00"
    }

    // MARK: - Actions

    private func handleCapturedImage(_ image: UIImage) {
        // Save the captured image using ImageManager
        if let imageURL = ImageManager.shared.saveReceiptImage(image) {
            print("Receipt image saved at: \(imageURL)")
            // TODO: Process the image with OCR and create expense entry
            // This will be implemented in later tasks
        } else {
            print("Failed to save receipt image")
        }

        showingCameraView = false
    }

    // Placeholder views for tabs
    private var homeView: some View {
        VStack {
            CustomNavigationBar(
                title: "Dashboard",
                showBackButton: false
            ) {
                Button(action: {}) {
                    Image(systemName: "bell")
                        .font(.system(size: 18))
                        .foregroundColor(AppTheme.primaryColor)
                        .padding(8)
                        .background(Color.white)
                        .cornerRadius(8)
                        .shadow(color: Color.black.opacity(0.1), radius: 2)
                }
                .accessibilityLabel("Notifications")
            }

            ScrollView {
                VStack(spacing: 20) {
                    // Demo content for home screen
                    CardView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Welcome to the ExpenseQuest Receipt Scanner")
                                .font(AppTheme.Typography.headingFont)
                                .foregroundColor(.primary)

                            Text("Scan your receipts to track expenses and manage your finances.")
                                .font(AppTheme.Typography.bodyFont)
                                .foregroundColor(.secondary)

                            PrimaryButton(title: "Scan Receipt") {
                                selectedTab = 1
                            }
                        }
                    }

                    // Real expense summary cards
                    summaryCardsView
                        .padding(.horizontal)

                    // Recent transactions section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Recent Transactions")
                                .font(AppTheme.Typography.subheadingFont)
                            Spacer()
                            Button("All >") { selectedTab = 2 }
                                .font(AppTheme.Typography.captionFont)
                                .foregroundColor(AppTheme.primaryColor)
                        }
                        .padding(.horizontal)

                        if expenseViewModel.isLoading {
                            // Loading state for recent transactions
                            ForEach(0..<3, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.secondarySystemBackground))
                                    .frame(height: 70)
                                    .redacted(reason: .placeholder)
                                    .shimmerEffect()
                                    .padding(.horizontal)
                            }
                        } else {
                            let recentExpenses = Array(expenseViewModel.displayedExpenses.prefix(3))
                            
                            if recentExpenses.isEmpty {
                                // Empty state for recent transactions
                                CardView {
                                    VStack(spacing: 8) {
                                        Image(systemName: "receipt")
                                            .font(.system(size: 32))
                                            .foregroundColor(.secondary)
                                        
                                        Text("No Recent Transactions")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        Text("Start by scanning your first receipt")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                }
                                .padding(.horizontal)
                            } else {
                                // Real recent transactions
                                ForEach(recentExpenses, id: \.id) { expense in
                                    ReceiptCard(
                                        merchantName: expense.merchant.isEmpty ? "Unknown Merchant" : expense.merchant,
                                        date: expense.date,
                                        amount: formatAmount(expense.amount),
                                        imageURL: expense.receipt?.imageURL,
                                        onTap: {
                                            // Navigate to expense detail
                                            selectedTab = 2
                                        }
                                    )
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                    .padding(.bottom)
                }
                .padding(.vertical)
            }
        }
        .background(AppTheme.backgroundColor)
    }

    private var scanPlaceholderView: some View {
        NavigationView {
            VStack {
                CustomNavigationBar(title: "Scan Receipt", showBackButton: false)

                Spacer()

                EmptyStateView(
                    title: "Scan Receipt",
                    message: "Capture your receipts to automatically extract expense information.",
                    systemImage: "camera.fill",
                    actionTitle: "Open Camera",
                    action: {
                        showingCameraView = true
                    }
                )

                Spacer()
            }
            .background(AppTheme.backgroundColor)
            .fullScreenCover(isPresented: $showingCameraView) {
                CameraCaptureView { capturedImage in
                    handleCapturedImage(capturedImage)
                }
            }
        }
    }

    private var expensesPlaceholderView: some View {
        ExpenseListView()
    }

    private var reportsPlaceholderView: some View {
        VStack {
            CustomNavigationBar(title: "Reports", showBackButton: false)

            CustomSegmentedControl(
                selection: .constant(0),
                options: ["Weekly", "Monthly", "Yearly"]
            )
            .padding(.top)

            Spacer()

            EmptyStateView(
                title: "Reports Coming Soon",
                message:
                    "Visualize your spending patterns and track your budget with detailed reports.",
                systemImage: "chart.bar.fill"
            )

            Spacer()
        }
        .background(AppTheme.backgroundColor)
    }

    private var settingsPlaceholderView: some View {
        NavigationView {
            VStack {
                CustomNavigationBar(title: "Settings", showBackButton: false)

                List {
                    Section(header: Text("Account")) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(AppTheme.Colors.primary)

                            Text("Profile")
                                .font(.body)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)

                        HStack {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 24))
                                .foregroundColor(AppTheme.Colors.primary)

                            Text("Notifications")
                                .font(.body)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                    }

                    Section(header: Text("Preferences")) {
                        NavigationLink(destination: SettingsView()) {
                            HStack {
                                Image(systemName: "paintbrush.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(AppTheme.Colors.primary)

                                Text("Appearance")
                                    .font(.body)

                                Spacer()

                                Text(ThemeManager.shared.currentTheme.displayName)
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 4)
                        }

                        HStack {
                            Image(systemName: "accessibility")
                                .font(.system(size: 24))
                                .foregroundColor(AppTheme.Colors.primary)

                            Text("Accessibility")
                                .font(.body)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                    }

                    Section(header: Text("Data")) {
                        NavigationLink(destination: SimpleRecurringListView()) {
                            HStack {
                                Image(systemName: "repeat")
                                    .font(.system(size: 24))
                                    .foregroundColor(AppTheme.Colors.primary)

                                Text("Recurring Expenses")
                                    .font(.body)

                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        
                        HStack {
                            Image(systemName: "icloud.fill")
                                .font(.system(size: 24))
                                .foregroundColor(AppTheme.Colors.primary)

                            Text("Sync & Backup")
                                .font(.body)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)

                        HStack {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 24))
                                .foregroundColor(AppTheme.Colors.primary)

                            Text("Privacy & Security")
                                .font(.body)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                    }

                    Section {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(AppTheme.Colors.primary)

                            Text("About")
                                .font(.body)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
        }
    }
}

// MARK: - View Extensions

extension View {
    func shimmerEffect() -> some View {
        self.overlay(
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.4), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .rotationEffect(.degrees(30))
                .offset(x: -200)
                .animation(
                    .easeInOut(duration: 1.5).repeatForever(autoreverses: false),
                    value: UUID()
                )
        )
        .clipped()
    }
}

#Preview {
    ContentView().environment(
        \.managedObjectContext, PersistenceController.preview.container.viewContext)
}
