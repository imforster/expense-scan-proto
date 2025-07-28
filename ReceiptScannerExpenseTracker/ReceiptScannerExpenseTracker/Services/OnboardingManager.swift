import SwiftUI
import Combine

#if canImport(UIKit)
import UIKit
#endif

class OnboardingManager: ObservableObject {
    static let shared = OnboardingManager()
    
    @Published var isOnboardingComplete: Bool = false
    @Published var currentOnboardingStep: OnboardingStep = .welcome
    @Published var onboardingProgress: OnboardingProgress
    
    private let userDefaults = UserDefaults.standard
    private let onboardingKey = "onboarding_progress"
    
    private init() {
        self.onboardingProgress = OnboardingProgress()
        loadOnboardingProgress()
    }
    
    func completeStep(_ step: OnboardingStep) {
        onboardingProgress.completedSteps.insert(step)
        onboardingProgress.lastCompletedStep = step
        
        // Auto-advance to next step
        if let nextStep = step.nextStep {
            currentOnboardingStep = nextStep
        } else {
            // All steps completed
            isOnboardingComplete = true
            onboardingProgress.isComplete = true
        }
        
        saveOnboardingProgress()
    }
    
    func skipStep(_ step: OnboardingStep) {
        onboardingProgress.skippedSteps.insert(step)
        
        if let nextStep = step.nextStep {
            currentOnboardingStep = nextStep
        } else {
            isOnboardingComplete = true
            onboardingProgress.isComplete = true
        }
        
        saveOnboardingProgress()
    }
    
    func resetOnboarding() {
        onboardingProgress = OnboardingProgress()
        currentOnboardingStep = .welcome
        isOnboardingComplete = false
        saveOnboardingProgress()
    }
    
    func resumeOnboarding() {
        if let lastStep = onboardingProgress.lastCompletedStep,
           let nextStep = lastStep.nextStep {
            currentOnboardingStep = nextStep
        } else {
            currentOnboardingStep = .welcome
        }
        isOnboardingComplete = false
    }
    
    private func loadOnboardingProgress() {
        if let data = userDefaults.data(forKey: onboardingKey),
           let progress = try? JSONDecoder().decode(OnboardingProgress.self, from: data) {
            self.onboardingProgress = progress
            self.isOnboardingComplete = progress.isComplete
            
            // Resume from last step if not complete
            if !progress.isComplete {
                if let lastStep = progress.lastCompletedStep,
                   let nextStep = lastStep.nextStep {
                    currentOnboardingStep = nextStep
                }
            }
        }
    }
    
    private func saveOnboardingProgress() {
        if let data = try? JSONEncoder().encode(onboardingProgress) {
            userDefaults.set(data, forKey: onboardingKey)
        }
    }
}

struct OnboardingProgress: Codable {
    var completedSteps: Set<OnboardingStep> = []
    var skippedSteps: Set<OnboardingStep> = []
    var lastCompletedStep: OnboardingStep?
    var isComplete: Bool = false
    var startedAt: Date = Date()
    var completedAt: Date?
    
    var progressPercentage: Double {
        let totalSteps = OnboardingStep.allCases.count
        let completedCount = completedSteps.count + skippedSteps.count
        return Double(completedCount) / Double(totalSteps)
    }
}

enum OnboardingStep: String, CaseIterable, Codable {
    case welcome
    case permissions
    case receiptScanningTutorial
    case expenseManagementTutorial
    case reportingTutorial
    case themeSelection
    
    var title: String {
        switch self {
        case .welcome:
            return "Welcome"
        case .permissions:
            return "Permissions"
        case .receiptScanningTutorial:
            return "Receipt Scanning"
        case .expenseManagementTutorial:
            return "Expense Management"
        case .reportingTutorial:
            return "Reports & Analytics"
        case .themeSelection:
            return "Theme Selection"
        }
    }
    
    var isSkippable: Bool {
        switch self {
        case .welcome, .permissions:
            return false
        case .receiptScanningTutorial, .expenseManagementTutorial, .reportingTutorial, .themeSelection:
            return true
        }
    }
    
    var nextStep: OnboardingStep? {
        let allSteps = OnboardingStep.allCases
        guard let currentIndex = allSteps.firstIndex(of: self),
              currentIndex + 1 < allSteps.count else {
            return nil
        }
        return allSteps[currentIndex + 1]
    }
}

// Main onboarding coordinator view
struct OnboardingCoordinatorView: View {
    @StateObject private var onboardingManager = OnboardingManager.shared
    @StateObject private var tutorialManager = TutorialManager.shared
    
    var body: some View {
        Group {
            if onboardingManager.isOnboardingComplete {
                ContentView()
            } else {
                onboardingStepView
            }
        }
        .animation(.easeInOut, value: onboardingManager.currentOnboardingStep)
    }
    
    @ViewBuilder
    private var onboardingStepView: some View {
        switch onboardingManager.currentOnboardingStep {
        case .welcome:
            OnboardingWelcomeView(isOnboardingComplete: .constant(false))
                .onReceive(NotificationCenter.default.publisher(for: .onboardingStepCompleted)) { notification in
                    if let step = notification.object as? OnboardingStep {
                        onboardingManager.completeStep(step)
                    }
                }
            
        case .permissions:
            PermissionRequestView(isPermissionFlowComplete: .constant(false))
                .onReceive(NotificationCenter.default.publisher(for: .onboardingStepCompleted)) { notification in
                    if let step = notification.object as? OnboardingStep {
                        onboardingManager.completeStep(step)
                    }
                }
            
        case .receiptScanningTutorial:
            TutorialContainerView(
                tutorial: TutorialManager.receiptScanningTutorial,
                onComplete: { onboardingManager.completeStep(.receiptScanningTutorial) },
                onSkip: { onboardingManager.skipStep(.receiptScanningTutorial) }
            )
            
        case .expenseManagementTutorial:
            TutorialContainerView(
                tutorial: TutorialManager.expenseManagementTutorial,
                onComplete: { onboardingManager.completeStep(.expenseManagementTutorial) },
                onSkip: { onboardingManager.skipStep(.expenseManagementTutorial) }
            )
            
        case .reportingTutorial:
            TutorialContainerView(
                tutorial: TutorialManager.reportingTutorial,
                onComplete: { onboardingManager.completeStep(.reportingTutorial) },
                onSkip: { onboardingManager.skipStep(.reportingTutorial) }
            )
            
        case .themeSelection:
            ThemeSelectionView(
                onComplete: { onboardingManager.completeStep(.themeSelection) },
                onSkip: { onboardingManager.skipStep(.themeSelection) }
            )
        }
    }
}

struct TutorialContainerView: View {
    let tutorial: Tutorial
    let onComplete: () -> Void
    let onSkip: () -> Void
    
    @State private var showTutorial = true
    
    var body: some View {
        ZStack {
            AppTheme.backgroundColor
                .ignoresSafeArea()
            
            if showTutorial {
                TutorialOverlayView(tutorial: tutorial, isPresented: $showTutorial)
                    .onChange(of: showTutorial) { _, isPresented in
                        if !isPresented {
                            onComplete()
                        }
                    }
            }
        }
        .navigationBarHidden(true)
    }
}

