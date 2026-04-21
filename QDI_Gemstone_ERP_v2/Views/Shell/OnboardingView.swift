import SwiftUI
import SwiftData

/// First-run wizard shown when no company profile is set.
struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("companyName") private var companyName: String = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("onboardingComplete") private var onboardingComplete: Bool = false

    @State private var step: Int = 0
    @State private var inputName: String = ""
    @State private var inputAddress: String = ""
    @State private var inputPhone: String = ""
    @State private var inputEmail: String = ""
    @State private var seedDemoData: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: AppSpacing.hero) {
                stepIndicator
                if step == 0 { welcomeStep }
                else if step == 1 { companyStep }
                else { finalStep }
            }
            .frame(maxWidth: 500)
            Spacer()
            navigationButtons
        }
        .padding(AppSpacing.hero)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appBackground()
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: AppSpacing.comfortable) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(i <= step ? AppColors.primary : AppColors.cardStroke)
                    .frame(width: 8, height: 8)
            }
        }
    }

    // MARK: - Step 0: Welcome

    private var welcomeStep: some View {
        VStack(spacing: AppSpacing.hero) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(AppColors.primary)
            Text("Welcome to QDI Gemstone ERP")
                .font(AppTypography.title)
                .foregroundStyle(AppColors.ink)
            Text("Let's set up your business profile. This only takes a moment.")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.inkMuted)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Step 1: Company Info

    private var companyStep: some View {
        VStack(alignment: .leading, spacing: AppSpacing.section) {
            Text("Company Information")
                .font(AppTypography.heading)
                .foregroundStyle(AppColors.ink)

            VStack(alignment: .leading, spacing: 4) {
                Text("Company Name").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
                TextField("e.g. Quality Diajewels Inc.", text: $inputName)
                    .glassField()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Phone").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
                TextField("e.g. +1 212-555-0100", text: $inputPhone)
                    .glassField()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Email").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
                TextField("e.g. info@company.com", text: $inputEmail)
                    .glassField()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Address").font(AppTypography.caption).foregroundStyle(AppColors.inkSubtle)
                TextField("e.g. 47th Street, New York, NY 10036", text: $inputAddress)
                    .glassField()
            }
        }
    }

    // MARK: - Step 2: Finish

    private var finalStep: some View {
        VStack(spacing: AppSpacing.hero) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(AppColors.success)
            Text("You're All Set!")
                .font(AppTypography.title)
                .foregroundStyle(AppColors.ink)

            Toggle("Load demo data to explore features", isOn: $seedDemoData)
                .toggleStyle(.checkbox)
                .foregroundStyle(AppColors.inkMuted)
                .font(AppTypography.body)
        }
    }

    // MARK: - Navigation

    private var navigationButtons: some View {
        HStack {
            if step > 0 {
                Button("Back") { withAnimation(reduceMotion ? nil : .default) { step -= 1 } }
                    .buttonStyle(.outline)
            }
            Spacer()
            if step < 2 {
                Button("Next", systemImage: "arrow.right") {
                    withAnimation(reduceMotion ? nil : .default) { step += 1 }
                }.buttonStyle(.gradient)
            } else {
                Button("Get Started", systemImage: "arrow.right") {
                    completeOnboarding()
                }.buttonStyle(.gradient)
            }
        }
        .padding(.bottom, AppSpacing.hero)
    }

    // MARK: - Complete

    private func completeOnboarding() {
        // Save company info
        UserDefaults.standard.set(inputName, forKey: "companyName")
        UserDefaults.standard.set(inputAddress, forKey: "companyAddress")
        UserDefaults.standard.set(inputPhone, forKey: "companyPhone")
        UserDefaults.standard.set(inputEmail, forKey: "companyEmail")
        companyName = inputName

        if seedDemoData {
            do {
                try DemoDataService.seedIfNeeded(modelContext: modelContext)
            } catch {
                AppLogger.data.error("Demo data seed failed: \(error.localizedDescription)")
            }
        }

        onboardingComplete = true
    }
}
