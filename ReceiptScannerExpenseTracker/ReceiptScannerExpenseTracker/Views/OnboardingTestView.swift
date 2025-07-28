import SwiftUI

/// Test view for onboarding flow - use this for debugging and testing
struct OnboardingTestView: View {
    @StateObject private var onboardingManager = OnboardingManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Onboarding Test Controls")
                .font(.title)
                .padding()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Current Status:")
                    .font(.headline)
                
                Text("Is Complete: \(onboardingManager.isOnboardingComplete ? "Yes" : "No")")
                Text("Current Step: \(onboardingManager.currentOnboardingStep.title)")
                Text("Progress: \(Int(onboardingManager.onboardingProgress.progressPercentage * 100))%")
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            VStack(spacing: 10) {
                Button("Reset Onboarding") {
                    onboardingManager.resetOnboarding()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Complete Current Step") {
                    onboardingManager.completeStep(onboardingManager.currentOnboardingStep)
                }
                .buttonStyle(.bordered)
                
                Button("Skip Current Step") {
                    onboardingManager.skipStep(onboardingManager.currentOnboardingStep)
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    OnboardingTestView()
}