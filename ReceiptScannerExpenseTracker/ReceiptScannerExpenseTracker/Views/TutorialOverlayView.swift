import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct TutorialOverlayView: View {
    let tutorial: Tutorial
    @Binding var isPresented: Bool
    @State private var currentStep = 0
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    // Prevent dismissal on background tap during tutorial
                }
            
            // Tutorial content
            VStack {
                Spacer()
                
                // Tutorial card
                VStack(spacing: 20) {
                    // Progress indicator
                    HStack {
                        ForEach(0..<tutorial.steps.count, id: \.self) { index in
                            Circle()
                                .fill(index <= currentStep ? Color.accentColor : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                    
                    // Current step content
                    if currentStep < tutorial.steps.count {
                        let step = tutorial.steps[currentStep]
                        
                        VStack(spacing: 16) {
                            Image(systemName: step.iconName)
                                .font(.system(size: 50))
                                .foregroundColor(.accentColor)
                            
                            Text(step.title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                            
                            Text(step.description)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    
                    // Navigation buttons
                    HStack {
                        if currentStep > 0 {
                            Button("Previous") {
                                withAnimation {
                                    currentStep -= 1
                                }
                            }
                            .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(currentStep == tutorial.steps.count - 1 ? "Got it!" : "Next") {
                            if currentStep == tutorial.steps.count - 1 {
                                isPresented = false
                                TutorialManager.shared.markTutorialCompleted(tutorial.id)
                            } else {
                                withAnimation {
                                    currentStep += 1
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    // Skip button
                    Button("Skip Tutorial") {
                        isPresented = false
                        TutorialManager.shared.markTutorialCompleted(tutorial.id)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding(24)
                .background(AppTheme.backgroundColor)
                .cornerRadius(16)
                .shadow(radius: 10)
                .padding(.horizontal, 20)
                
                Spacer()
            }
        }
    }
}

struct Tutorial {
    let id: String
    let title: String
    let steps: [TutorialStep]
}

struct TutorialStep {
    let title: String
    let description: String
    let iconName: String
}

class TutorialManager: ObservableObject {
    static let shared = TutorialManager()
    
    @Published var completedTutorials: Set<String> = []
    
    private init() {
        loadCompletedTutorials()
    }
    
    func markTutorialCompleted(_ tutorialId: String) {
        completedTutorials.insert(tutorialId)
        saveCompletedTutorials()
    }
    
    func isTutorialCompleted(_ tutorialId: String) -> Bool {
        return completedTutorials.contains(tutorialId)
    }
    
    private func loadCompletedTutorials() {
        if let data = UserDefaults.standard.data(forKey: "completedTutorials"),
           let tutorials = try? JSONDecoder().decode(Set<String>.self, from: data) {
            completedTutorials = tutorials
        }
    }
    
    private func saveCompletedTutorials() {
        if let data = try? JSONEncoder().encode(completedTutorials) {
            UserDefaults.standard.set(data, forKey: "completedTutorials")
        }
    }
    
    // Predefined tutorials
    static let receiptScanningTutorial = Tutorial(
        id: "receipt_scanning",
        title: "Receipt Scanning",
        steps: [
            TutorialStep(
                title: "Position Your Receipt",
                description: "Hold your device steady and position the receipt within the camera frame. Make sure all corners are visible.",
                iconName: "viewfinder"
            ),
            TutorialStep(
                title: "Capture the Image",
                description: "Tap the capture button when the receipt is clearly visible and well-lit. The app will automatically detect the receipt.",
                iconName: "camera.circle"
            ),
            TutorialStep(
                title: "Review Extracted Data",
                description: "Check the automatically extracted information like date, amount, and vendor. Edit any incorrect details before saving.",
                iconName: "doc.text.magnifyingglass"
            )
        ]
    )
    
    static let expenseManagementTutorial = Tutorial(
        id: "expense_management",
        title: "Expense Management",
        steps: [
            TutorialStep(
                title: "Categorize Expenses",
                description: "Assign categories to your expenses for better organization. The app learns from your choices and suggests categories automatically.",
                iconName: "folder.badge.gearshape"
            ),
            TutorialStep(
                title: "Add Tags and Notes",
                description: "Use tags and notes to add context to your expenses. This helps with searching and reporting later.",
                iconName: "tag"
            ),
            TutorialStep(
                title: "Split Receipts",
                description: "For receipts with multiple items, you can split them into separate expenses for more detailed tracking.",
                iconName: "scissors"
            )
        ]
    )
    
    static let reportingTutorial = Tutorial(
        id: "reporting",
        title: "Reports & Analytics",
        steps: [
            TutorialStep(
                title: "View Spending Trends",
                description: "Access the Reports tab to see your spending patterns over time with interactive charts and graphs.",
                iconName: "chart.line.uptrend.xyaxis"
            ),
            TutorialStep(
                title: "Filter and Analyze",
                description: "Use filters to analyze spending by category, date range, or vendor to gain insights into your habits.",
                iconName: "slider.horizontal.3"
            ),
            TutorialStep(
                title: "Export Reports",
                description: "Export your expense data as PDF or CSV files for tax purposes or sharing with accountants.",
                iconName: "square.and.arrow.up"
            )
        ]
    )
}