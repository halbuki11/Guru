import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var userManager = UserManager.shared

    @State private var editName: String = ""
    @State private var editEmail: String = ""
    @State private var editBio: String = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var avatarImage: Image?
    @State private var isSaving = false
    @State private var showSavedToast = false

    var body: some View {
        NavigationStack {
            Form {
                // Avatar section
                avatarSection

                // Profile info section
                profileInfoSection

                // Account info section
                accountInfoSection

                // Save button
                Section {
                    Button {
                        saveProfile()
                    } label: {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("profile.save".localized)
                                    .font(.custom("SpaceMono-Bold", size: 17))
                            }
                            Spacer()
                        }
                        .foregroundStyle(.white)
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(AppColors.primary)
                    .disabled(isSaving)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .navigationTitle("profile.edit".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                    .foregroundStyle(AppColors.textSecondary)
                }
            }
            .onAppear {
                editName = userManager.userName ?? UserDefaults.standard.string(forKey: "userName") ?? ""
                editEmail = userManager.userEmail ?? ""
                editBio = UserDefaults.standard.string(forKey: "userBio") ?? ""
                loadSavedAvatar()
            }
            .overlay {
                if showSavedToast {
                    VStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppColors.success)
                            Text("profile.saved".localized)
                                .font(ThemeManager.Typography.subheadline)
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(AppColors.surface)
                        .cornerRadius(25)
                        .shadow(color: .black.opacity(0.3), radius: 10)
                        .padding(.bottom, 30)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.4), value: showSavedToast)
                }
            }
        }
    }

    // MARK: - Avatar Section
    private var avatarSection: some View {
        Section {
            HStack {
                Spacer()

                VStack(spacing: ThemeManager.Spacing.md) {
                    // Avatar image
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [AppColors.primary, AppColors.primary.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)

                        if let avatarImage = avatarImage {
                            avatarImage
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        } else {
                            Text(userManager.displayInitials)
                                .font(.custom("SpaceMono-Bold", size: 36))
                                .foregroundStyle(.white)
                        }
                    }
                    .overlay(Circle().stroke(AppColors.primary.opacity(0.3), lineWidth: 3))

                    // Photo picker
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        HStack(spacing: 6) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 12))
                            Text("editProfile.changePhoto".localized)
                                .font(ThemeManager.Typography.subheadline)
                        }
                        .foregroundStyle(AppColors.primary)
                    }
                    .onChange(of: selectedPhoto) { _, newValue in
                        loadSelectedPhoto(newValue)
                    }
                }

                Spacer()
            }
            .padding(.vertical, ThemeManager.Spacing.md)
        }
        .listRowBackground(AppColors.surface)
    }

    // MARK: - Profile Info Section
    private var profileInfoSection: some View {
        Section {
            // Full name
            VStack(alignment: .leading, spacing: ThemeManager.Spacing.xxs) {
                Text("profile.name".localized)
                    .font(ThemeManager.Typography.caption1)
                    .foregroundStyle(AppColors.textTertiary)

                TextField("profile.namePlaceholder".localized, text: $editName)
                    .textFieldStyle(.plain)
                    .foregroundStyle(AppColors.textPrimary)
                    .textContentType(.name)
                    .autocorrectionDisabled()
            }

            // Email
            VStack(alignment: .leading, spacing: ThemeManager.Spacing.xxs) {
                Text("profile.email".localized)
                    .font(ThemeManager.Typography.caption1)
                    .foregroundStyle(AppColors.textTertiary)

                TextField("profile.emailPlaceholder".localized, text: $editEmail)
                    .textFieldStyle(.plain)
                    .foregroundStyle(AppColors.textPrimary)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            }

            // Bio
            VStack(alignment: .leading, spacing: ThemeManager.Spacing.xxs) {
                Text("editProfile.aboutMe".localized)
                    .font(ThemeManager.Typography.caption1)
                    .foregroundStyle(AppColors.textTertiary)

                TextField("editProfile.bioPlaceholder".localized, text: $editBio, axis: .vertical)
                    .textFieldStyle(.plain)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(3...6)
            }
        } header: {
            Text("profile.personalInfo".localized)
        }
        .listRowBackground(AppColors.surface)
    }

    // MARK: - Account Info Section
    private var accountInfoSection: some View {
        Section {
            // User ID
            VStack(alignment: .leading, spacing: 4) {
                Text("profile.userId".localized)
                    .font(ThemeManager.Typography.caption1)
                    .foregroundStyle(AppColors.textTertiary)

                Text(userManager.userId.map { String($0.prefix(16)) + "..." } ?? "-")
                    .font(.custom("SpaceMono-Regular", size: 13))
                    .foregroundStyle(AppColors.textTertiary)
            }

            // Apple connection
            HStack {
                Image(systemName: "apple.logo")
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(width: 24)

                Text("profile.connectedApple".localized)
                    .font(ThemeManager.Typography.body)
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppColors.success)
            }
        } header: {
            Text("profile.account".localized)
        }
        .listRowBackground(AppColors.surface)
    }

    // MARK: - Actions

    private func loadSavedAvatar() {
        if let imageData = UserDefaults.standard.data(forKey: "userAvatarData"),
           let uiImage = UIImage(data: imageData) {
            avatarImage = Image(uiImage: uiImage)
        }
    }

    private func loadSelectedPhoto(_ item: PhotosPickerItem?) {
        guard let item = item else { return }

        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                // Save to UserDefaults
                UserDefaults.standard.set(data, forKey: "userAvatarData")

                if let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        avatarImage = Image(uiImage: uiImage)
                    }
                }
            }
        }
    }

    private func saveProfile() {
        isSaving = true

        let trimmedName = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = editEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBio = editBio.trimmingCharacters(in: .whitespacesAndNewlines)

        // Save name
        if !trimmedName.isEmpty {
            userManager.updateName(trimmedName)
        }

        // Save email
        if !trimmedEmail.isEmpty {
            userManager.updateEmail(trimmedEmail)
        }

        // Save bio to UserDefaults
        UserDefaults.standard.set(trimmedBio, forKey: "userBio")

        // Show saved toast
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSaving = false
            withAnimation {
                showSavedToast = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    showSavedToast = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    EditProfileView()
}
