import SwiftUI

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var isCreateAccount = false

    private var auth: SupabaseAuthService { SupabaseAuthService.shared }

    var body: some View {
        ZStack {
            AppColors.panelBackground // #0A0A0F
                .ignoresSafeArea()

            VStack(spacing: AppSpacing.hero) {
                // Logo / Title
                VStack(spacing: AppSpacing.standard) {
                    Image(systemName: "sparkle")
                        .font(AppTypography.displayTitle)
                        .foregroundStyle(AppColors.primary)

                    Text("QDI Gemstone ERP")
                        .font(AppTypography.title)
                        .foregroundStyle(AppColors.ink)

                    Text(isCreateAccount ? "Create your account" : "Sign in to continue")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.inkMuted)
                }

                // Form fields
                VStack(spacing: AppSpacing.comfortable) {
                    VStack(alignment: .leading, spacing: AppSpacing.compact) {
                        Text("Email")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.inkSubtle)
                        TextField("Email", text: $email)
                            .textFieldStyle(.plain)
                            .textContentType(.emailAddress)
                            .font(AppTypography.body)
                            .padding(.horizontal, AppSpacing.standard)
                            .frame(height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                                    .fill(AppColors.cardBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                                    .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                            )
                    }

                    VStack(alignment: .leading, spacing: AppSpacing.compact) {
                        Text("Password")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.inkSubtle)
                        SecureField("Password", text: $password)
                            .textFieldStyle(.plain)
                            .font(AppTypography.body)
                            .padding(.horizontal, AppSpacing.standard)
                            .frame(height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                                    .fill(AppColors.cardBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: AppCornerRadius.card, style: .continuous)
                                    .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                            )
                    }
                }
                .frame(maxWidth: 320)

                // Sign In / Create button
                VStack(spacing: AppSpacing.standard) {
                    Button {
                        Task {
                            if isCreateAccount {
                                await auth.signUp(email: email, password: password)
                            } else {
                                await auth.signIn(email: email, password: password)
                            }
                            if auth.isAuthenticated {
                                dismiss()
                            }
                        }
                    } label: {
                        Group {
                            if auth.isLoading {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text(isCreateAccount ? "Create Account" : "Sign In")
                            }
                        }
                        .frame(maxWidth: 320)
                        .frame(height: 32)
                    }
                    .buttonStyle(.gradient)
                    .disabled(email.isEmpty || password.isEmpty || auth.isLoading)

                    // Error display
                    if let error = auth.authError {
                        Text(error)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.danger)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 320)
                    }

                    // Toggle
                    Button {
                        isCreateAccount.toggle()
                        auth.authError = nil
                    } label: {
                        Text(isCreateAccount ? "Already have an account? Sign In" : "Don't have an account? Create one")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(AppSpacing.hero)
        }
        .frame(minWidth: 440, minHeight: 480)
    }
}
