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
                            Text("Welcome to Receipt Scanner")
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

                    // Sample expense summary cards
                    HStack(spacing: 12) {
                        ExpenseSummaryCard(
                            title: "This Month",
                            amount: "1,245.50",
                            trend: 5.2,
                            color: AppTheme.primaryColor
                        )

                        ExpenseSummaryCard(
                            title: "Last Month",
                            amount: "1,183.75",
                            trend: -2.8,
                            color: AppTheme.secondaryColor
                        )
                    }
                    .padding(.horizontal)

                    // Recent transactions section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Transactions")
                            .font(AppTheme.Typography.subheadingFont)
                            .padding(.horizontal)

                        // Sample receipt cards
                        ReceiptCard(
                            merchantName: "Grocery Store",
                            date: Date(),
                            amount: "56.78",
                            imageURL: nil,
                            onTap: {}
                        )
                        .padding(.horizontal)

                        ReceiptCard(
                            merchantName: "Coffee Shop",
                            date: Date().addingTimeInterval(-86400),
                            amount: "4.50",
                            imageURL: nil,
                            onTap: {}
                        )
                        .padding(.horizontal)

                        SecondaryButton(title: "View All Expenses") {
                            selectedTab = 2
                        }
                    }
                    .padding(.top)
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

#Preview {
    ContentView().environment(
        \.managedObjectContext, PersistenceController.preview.container.viewContext)
}
