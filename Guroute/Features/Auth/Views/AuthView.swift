import SwiftUI

/// ⚠️ DEPRECATED: AuthView artık kullanılmıyor.
/// Giriş işlemi SettingsView içinde Apple Sign In ile yapılıyor.
/// Bu dosya sadece Xcode build referanslarını kırmamak için duruyor.
/// İleride tamamen kaldırılabilir.
struct AuthView: View {
    var body: some View {
        // Kullanılmıyor — SettingsView'daki Apple Sign In aktif
        EmptyView()
    }
}

// MARK: - Custom Text Field (başka yerlerde kullanılıyor olabilir)
struct CustomTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false

    var body: some View {
        HStack(spacing: ThemeManager.Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(AppColors.textTertiary)
                .frame(width: 24)

            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
        .padding(ThemeManager.Spacing.sm)
        .background(AppColors.surfaceLight)
        .cornerRadius(ThemeManager.CornerRadius.small)
        .foregroundStyle(AppColors.textPrimary)
    }
}
