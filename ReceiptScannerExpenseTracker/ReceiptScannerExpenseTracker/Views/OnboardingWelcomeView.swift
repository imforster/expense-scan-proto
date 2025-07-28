import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct OnboardingWelcomeView: View {
    @State private var currentPage = 0
    @State private var animateContent = false
    @State private var showProgressBar = false
    @Binding var isOnboardingComplete: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    internal let pages = [
        OnboardingPage(
            title: "Welcome to Receipt Scanner",
            subtitle: "Your smart expense tracking companion",
            imageName: "doc.text.viewfinder",
            description: "Transform your receipts into organized expense data with just a tap. Say goodbye to manual entry and hello to effortless expense tracking.",
            backgroundColor: Color.blue.opacity(0.1),
            accentColor: Color.blue
        ),
        OnboardingPage(
            title: "Instant Receipt Scanning",
            subtitle: "Capture and extract data automatically",
            imageName: "camera.viewfinder",
            description: "Point your camera at any receipt and watch as we automatically extract merchant, date, amount, and itemized details with advanced OCR technology.",
            backgroundColor: Color.green.opacity(0.1),
            accentColor: Color.green
        ),
        OnboardingPage(
            title: "Smart Categorization",
            subtitle: "AI-powered expense organization",
            imageName: "brain.head.profile",
            description: "Our intelligent system learns your spending patterns and automatically categorizes expenses, making tax time and budgeting a breeze.",
            backgroundColor: Color.orange.opacity(0.1),
            accentColor: Color.orange
        ),
        OnboardingPage(
            title: "Powerful Analytics",
            subtitle: "Insights that drive better decisions",
            imageName: "chart.line.uptrend.xyaxis",
            description: "Visualize your spending trends, track budgets, and export detailed reports. Make informed financial decisions with comprehensive analytics.",
            backgroundColor: Color.purple.opacity(0.1),
            accentColor: Color.purple
        ),
        OnboardingPage(
            title: "Secure & Private",
            subtitle: "Your financial data, protected",
            imageName: "lock.shield.fill",
            description: "Bank-level encryption keeps your financial information secure. All data is stored locally on your device with optional encrypted cloud sync.",
            backgroundColor: Color.green.opacity(0.1),
            accentColor: Color.green
        )
    ]
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // App branding header
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.viewfinder")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(AppTheme.primaryColor)
                        .scaleEffect(animateContent ? 1.0 : 0.8)
                        .opacity(animateContent ? 1.0 : 0.0)
                    
                    Text("Receipt Scanner")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.labelColor)
                        .opacity(animateContent ? 1.0 : 0.0)
                }
                .padding(.top, 20)
                .animation(reduceMotion ? .none : .easeOut(duration: 0.8).delay(0.2), value: animateContent)
                
                // Progress bar
                if showProgressBar {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Step \(currentPage + 1) of \(pages.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int((Double(currentPage + 1) / Double(pages.count)) * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        ProgressView(value: Double(currentPage + 1), total: Double(pages.count))
                            .progressViewStyle(LinearProgressViewStyle(tint: pages[currentPage].accentColor))
                            .scaleEffect(y: 2)
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, 16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                // Main content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(
                            page: pages[index],
                            isActive: index == currentPage,
                            geometry: geometry
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(reduceMotion ? .none : .easeInOut(duration: 0.5), value: currentPage)
                .onChange(of: currentPage) { _ in
                    #if canImport(UIKit)
                    if !reduceMotion {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }
                    #endif
                }
                
                // Enhanced page indicator with progress
                HStack(spacing: 12) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(index == currentPage ? pages[currentPage].accentColor : Color.gray.opacity(0.3))
                            .frame(width: index == currentPage ? 24 : 8, height: 8)
                            .animation(reduceMotion ? .none : .easeInOut(duration: 0.3), value: currentPage)
                    }
                }
                .padding(.vertical, 24)
                
                // Enhanced navigation controls
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        // Back button
                        if currentPage > 0 {
                            Button(action: {
                                withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.3)) {
                                    currentPage -= 1
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 14, weight: .medium))
                                    Text("Back")
                                        .font(.system(size: 16, weight: .medium))
                                }
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(AppTheme.systemGray6Color)
                                .cornerRadius(25)
                            }
                            .accessibilityLabel("Go back to previous step")
                        } else {
                            Spacer()
                        }
                        
                        Spacer()
                        
                        // Next/Get Started button
                        Button(action: {
                            if currentPage == pages.count - 1 {
                                NotificationCenter.default.post(
                                    name: .onboardingStepCompleted,
                                    object: OnboardingStep.welcome
                                )
                            } else {
                                withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.3)) {
                                    currentPage += 1
                                }
                            }
                        }) {
                            HStack(spacing: 8) {
                                Text(currentPage == pages.count - 1 ? "Get Started" : "Continue")
                                    .font(.system(size: 16, weight: .semibold))
                                
                                if currentPage < pages.count - 1 {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .medium))
                                } else {
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 14, weight: .medium))
                                }
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 14)
                            .background(pages[currentPage].accentColor)
                            .cornerRadius(25)
                            .shadow(color: pages[currentPage].accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .accessibilityLabel(currentPage == pages.count - 1 ? "Get started with the app" : "Continue to next step")
                        .scaleEffect(animateContent ? 1.0 : 0.9)
                        .animation(reduceMotion ? .none : .spring(response: 0.6, dampingFraction: 0.8), value: animateContent)
                    }
                    
                    // Skip option for non-essential steps
                    if currentPage > 0 && currentPage < pages.count - 1 {
                        Button("Skip Introduction") {
                            withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.3)) {
                                currentPage = pages.count - 1
                            }
                        }
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .accessibilityLabel("Skip to final step")
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, geometry.safeAreaInsets.bottom + 20)
            }
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    AppTheme.backgroundColor,
                    pages[currentPage].backgroundColor
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .animation(reduceMotion ? .none : .easeInOut(duration: 0.8), value: currentPage)
        )
        .onAppear {
            withAnimation(reduceMotion ? .none : .easeOut(duration: 0.6)) {
                animateContent = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.4)) {
                    showProgressBar = true
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Welcome screen, step \(currentPage + 1) of \(pages.count)")
    }
}

#Preview {
    OnboardingWelcomeView(isOnboardingComplete: .constant(false))
}

struct OnboardingPage {
    let title: String
    let subtitle: String
    let imageName: String
    let description: String
    let backgroundColor: Color
    let accentColor: Color
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    let isActive: Bool
    let geometry: GeometryProxy
    
    @State private var animateIcon = false
    @State private var animateText = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 20)
            
            // Icon with enhanced animation
            ZStack {
                Circle()
                    .fill(page.accentColor.opacity(0.1))
                    .frame(width: 140, height: 140)
                    .scaleEffect(animateIcon ? 1.0 : 0.8)
                    .opacity(animateIcon ? 1.0 : 0.0)
                
                Circle()
                    .fill(page.accentColor.opacity(0.05))
                    .frame(width: 180, height: 180)
                    .scaleEffect(animateIcon ? 1.0 : 0.6)
                    .opacity(animateIcon ? 1.0 : 0.0)
                
                Image(systemName: page.imageName)
                    .font(.system(size: 60, weight: .light))
                    .foregroundColor(page.accentColor)
                    .scaleEffect(animateIcon ? 1.0 : 0.5)
                    .opacity(animateIcon ? 1.0 : 0.0)
                    .rotationEffect(.degrees(animateIcon ? 0 : -10))
            }
            .animation(reduceMotion ? .none : .spring(response: 0.8, dampingFraction: 0.6).delay(0.2), value: animateIcon)
            
            Spacer(minLength: 40)
            
            // Text content with staggered animation
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Text(page.title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.labelColor)
                        .multilineTextAlignment(.center)
                        .opacity(animateText ? 1.0 : 0.0)
                        .offset(y: animateText ? 0 : 20)
                        .animation(reduceMotion ? .none : .easeOut(duration: 0.6).delay(0.4), value: animateText)
                    
                    Text(page.subtitle)
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(page.accentColor)
                        .multilineTextAlignment(.center)
                        .opacity(animateText ? 1.0 : 0.0)
                        .offset(y: animateText ? 0 : 20)
                        .animation(reduceMotion ? .none : .easeOut(duration: 0.6).delay(0.6), value: animateText)
                }
                
                Text(page.description)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(AppTheme.secondaryLabelColor)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .opacity(animateText ? 1.0 : 0.0)
                    .offset(y: animateText ? 0 : 20)
                    .animation(reduceMotion ? .none : .easeOut(duration: 0.6).delay(0.8), value: animateText)
            }
            .padding(.horizontal, 32)
            
            Spacer(minLength: 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: isActive) { active in
            if active {
                // Reset animations when page becomes active
                animateIcon = false
                animateText = false
                
                // Trigger animations with delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    animateIcon = true
                    animateText = true
                }
            }
        }
        .onAppear {
            if isActive {
                // Initial animation for first page
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    animateIcon = true
                    animateText = true
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(page.title). \(page.subtitle). \(page.description)")
    }
}