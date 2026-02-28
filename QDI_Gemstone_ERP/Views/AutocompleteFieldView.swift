import SwiftUI

/// Keyboard-first autocomplete text field. Tab commits best match and moves to next field.
struct AutocompleteFieldView: View {
    let label: String
    @Binding var text: String
    let options: [String]
    var placeholder: String = ""
    var showLabel: Bool = true
    var onSubmit: (() -> Void)?

    @State private var showSuggestions = false
    @FocusState private var isFocused: Bool

    private var matches: [String] {
        let t = text.trimmingCharacters(in: .whitespaces).lowercased()
        if t.isEmpty { return Array(options.prefix(12)) }
        return options.filter { $0.lowercased().hasPrefix(t) || $0.lowercased().contains(t) }
            .prefix(12)
            .map { String($0) }
    }

    private var bestMatch: String? {
        let t = text.trimmingCharacters(in: .whitespaces).lowercased()
        if t.isEmpty { return options.first }
        return matches.first { $0.lowercased().hasPrefix(t) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showLabel && !label.isEmpty {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onChange(of: text) { _, _ in showSuggestions = isFocused }
                .onSubmit { commitAndAdvance() }
                .onExitCommand { showSuggestions = false }
        }
        .overlay(alignment: .topLeading) {
            if showSuggestions && isFocused && !matches.isEmpty {
                suggestionsDropdown
            }
        }
        .onChange(of: isFocused) { _, focused in
            if !focused { commitValue() }
            showSuggestions = focused
        }
    }

    private var suggestionsDropdown: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(matches, id: \.self) { opt in
                Button {
                    text = opt
                    showSuggestions = false
                    commitAndAdvance()
                } label: {
                    HStack {
                        Text(opt)
                            .foregroundStyle(.primary)
                        if opt == bestMatch {
                            Text("Tab")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(minWidth: 140, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 2)
        .padding(.top, 28)
        .zIndex(1000)
    }

    private func commitValue() {
        if let match = bestMatch, !match.isEmpty { text = match }
        showSuggestions = false
    }

    private func commitAndAdvance() {
        commitValue()
        onSubmit?()
    }
}
