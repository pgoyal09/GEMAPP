import SwiftUI

struct AutocompleteTextField: View {
    @Binding var text: String
    let options: [String]
    let label: String
    @State private var showSuggestions = false
    @FocusState private var isFocused: Bool

    private var filteredOptions: [String] {
        guard !text.isEmpty else { return options }
        return options.filter { $0.localizedCaseInsensitiveContains(text) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField(label, text: $text)
                .textFieldStyle(.plain)
                .font(AppTypography.body)
                .padding(.horizontal, AppSpacing.standard)
                .frame(height: 28)
                .background(
                    RoundedRectangle(cornerRadius: AppCornerRadius.field, style: .continuous)
                        .fill(AppColors.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.field, style: .continuous)
                        .strokeBorder(isFocused ? AppColors.primary : AppColors.cardStroke, lineWidth: isFocused ? 1.5 : 1)
                )
                .focused($isFocused)
                .onChange(of: isFocused) { _, focused in
                    showSuggestions = focused
                }
                .onChange(of: text) { _, _ in
                    showSuggestions = isFocused
                }

            if showSuggestions && !filteredOptions.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(filteredOptions.prefix(8), id: \.self) { option in
                            Button {
                                text = option
                                showSuggestions = false
                            } label: {
                                Text(option)
                                    .font(AppTypography.body)
                                    .foregroundStyle(AppColors.ink)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, AppSpacing.standard)
                                    .padding(.vertical, AppSpacing.compact)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 160)
                .background(
                    RoundedRectangle(cornerRadius: AppCornerRadius.field, style: .continuous)
                        .fill(AppColors.cardElevated.opacity(0.2))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.field, style: .continuous)
                        .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                )
                .zIndex(10)
                .shadow(color: Color.black.opacity(0.3), radius: 8)
            }
        }
    }
}
