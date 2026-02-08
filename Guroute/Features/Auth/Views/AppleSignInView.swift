import SwiftUI
import AuthenticationServices

struct AppleSignInView: View {
    @StateObject private var userManager = UserManager.shared
    @State private var isSigningIn = false
    @State private var showError = false
    @State private var errorMessage = ""

    // Animation states
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0
    @State private var contentOpacity: Double = 0
    @State private var buttonOffset: CGFloat = 50

    var body: some View {
        ZStack {
            // Background gradient
            AppColors.heroMeshGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo and welcome section
                VStack(spacing: ThemeManager.Spacing.lg) {
                    // App logo
                    ZStack {
                        // Glow effect
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [AppColors.primary.opacity(0.3), .clear],
                                    center: .center,
                                    startRadius: 30,
                                    endRadius: 80
                                )
                            )
                            .frame(width: 160, height: 160)

                        // Icon
                        Image(systemName: "airplane.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(AppColors.primaryGradient)
                    }
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)

                    // Welcome text
                    VStack(spacing: ThemeManager.Spacing.xs) {
                        Text("signIn.welcomeTo".localized)
                            .font(ThemeManager.Typography.title3)
                            .foregroundStyle(AppColors.textSecondary)

                        Text("GUROUTE")
                            .font(ThemeManager.Typography.displaySmall)
                            .foregroundStyle(AppColors.textPrimary)
                            .tracking(4)

                        Text("signIn.travelAssistant".localized)
                            .font(ThemeManager.Typography.subheadline)
                            .foregroundStyle(AppColors.textTertiary)
                    }
                    .opacity(contentOpacity)
                }

                Spacer()

                // Sign in section
                VStack(spacing: ThemeManager.Spacing.lg) {
                    // Subtitle
                    Text("signIn.subtitle".localized)
                        .font(ThemeManager.Typography.body)
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, ThemeManager.Spacing.xl)

                    // Apple Sign In button
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        handleSignInResult(result)
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .cornerRadius(12)
                    .padding(.horizontal, ThemeManager.Spacing.xl)
                    .disabled(isSigningIn)
                    .opacity(isSigningIn ? 0.6 : 1)

                    // Privacy note
                    HStack(spacing: ThemeManager.Spacing.xs) {
                        Image(systemName: "lock.shield.fill")
                            .font(.caption)
                            .foregroundStyle(AppColors.textTertiary)

                        Text("signIn.privacyNote".localized)
                            .font(ThemeManager.Typography.caption2)
                            .foregroundStyle(AppColors.textTertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, ThemeManager.Spacing.xl)
                }
                .offset(y: buttonOffset)
                .opacity(contentOpacity)

                Spacer()
                    .frame(height: ThemeManager.Spacing.xxl)
            }

            // Loading overlay
            if isSigningIn {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()

                VStack(spacing: ThemeManager.Spacing.md) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)

                    Text("common.loading".localized)
                        .font(ThemeManager.Typography.subheadline)
                        .foregroundStyle(.white)
                }
            }
        }
        .alert("common.error".localized, isPresented: $showError) {
            Button("common.close".localized) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        // Logo animation
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }

        // Content fade in
        withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
            contentOpacity = 1.0
        }

        // Button slide up
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.4)) {
            buttonOffset = 0
        }
    }

    private func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                showError(message: "authError.unknown".localized)
                return
            }

            isSigningIn = true

            Task {
                // Process the credential
                let userIdentifier = appleIDCredential.user
                let email = appleIDCredential.email
                let fullName = appleIDCredential.fullName

                // Build full name string
                var nameString: String? = nil
                if let givenName = fullName?.givenName {
                    nameString = givenName
                    if let familyName = fullName?.familyName {
                        nameString = "\(givenName) \(familyName)"
                    }
                }

                // Save to UserManager
                await userManager.processAppleSignIn(
                    userIdentifier: userIdentifier,
                    email: email,
                    fullName: nameString
                )

                isSigningIn = false
            }

        case .failure(let error):
            // User cancelled or error occurred
            let nsError = error as NSError
            if nsError.code != ASAuthorizationError.canceled.rawValue {
                showError(message: error.localizedDescription)
            }
        }
    }

    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}

#Preview {
    AppleSignInView()
        .preferredColorScheme(.dark)
}
