import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentPage = 0

    private var pages: [OnboardingPage] {
        [
            OnboardingPage(
                image: "airplane.circle.fill",
                title: "onboarding.feature1.title".localized,
                description: "onboarding.feature1.desc".localized
            ),
            OnboardingPage(
                image: "map.fill",
                title: "onboarding.feature2.title".localized,
                description: "onboarding.feature2.desc".localized
            ),
            OnboardingPage(
                image: "book.closed.fill",
                title: "onboarding.feature3.title".localized,
                description: "onboarding.feature3.desc".localized
            ),
            OnboardingPage(
                image: "sparkles",
                title: "onboarding.ready.title".localized,
                description: "onboarding.ready.desc".localized
            )
        ]
    }

    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        pageView(for: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                // Bottom section
                VStack(spacing: ThemeManager.Spacing.lg) {
                    // Page indicators
                    HStack(spacing: ThemeManager.Spacing.xs) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? AppColors.primary : AppColors.textTertiary)
                                .frame(width: 8, height: 8)
                                .animation(.easeInOut, value: currentPage)
                        }
                    }

                    // Buttons
                    if currentPage == pages.count - 1 {
                        Button {
                            completeOnboarding()
                        } label: {
                            Text("onboarding.getStarted".localized)
                                .frame(maxWidth: .infinity)
                        }
                        .primaryButton()
                    } else {
                        HStack {
                            Button {
                                completeOnboarding()
                            } label: {
                                Text("onboarding.skip".localized)
                                    .font(ThemeManager.Typography.subheadline)
                                    .foregroundStyle(AppColors.textSecondary)
                            }

                            Spacer()

                            Button {
                                withAnimation {
                                    currentPage += 1
                                }
                            } label: {
                                HStack {
                                    Text("common.next".localized)
                                    Image(systemName: "arrow.right")
                                }
                            }
                            .primaryButton()
                        }
                    }
                }
                .padding(.horizontal, ThemeManager.Spacing.lg)
                .padding(.bottom, ThemeManager.Spacing.xl)
            }
        }
    }

    private func pageView(for page: OnboardingPage) -> some View {
        VStack(spacing: ThemeManager.Spacing.xl) {
            Spacer()

            // Icon
            Image(systemName: page.image)
                .font(.system(size: 100))
                .foregroundStyle(AppColors.primary)
                .symbolEffect(.bounce, value: currentPage)

            // Title
            Text(page.title)
                .font(ThemeManager.Typography.title1)
                .foregroundStyle(AppColors.textPrimary)
                .multilineTextAlignment(.center)

            // Description
            Text(page.description)
                .font(ThemeManager.Typography.body)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, ThemeManager.Spacing.xl)

            Spacer()
            Spacer()
        }
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        appState.showOnboarding = false
    }
}

struct OnboardingPage {
    let image: String
    let title: String
    let description: String
}

#Preview {
    OnboardingView()
        .environmentObject(AppState())
}
