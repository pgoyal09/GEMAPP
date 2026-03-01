import SwiftUI

private struct TextWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// Autocomplete text field. Dropdown shows only when button is pressed; inline gray hint shows best match.
struct AutocompleteFieldView: View {
    let label: String
    @Binding var text: String
    let options: [String]
    var placeholder: String = ""
    var showLabel: Bool = true
    var onSubmit: (() -> Void)?

    @State private var showSuggestions = false
    @State private var typedTextWidth: CGFloat = 0
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

    /// Suffix of bestMatch after the current text (for inline gray hint)
    private var completionSuffix: String {
        guard let match = bestMatch, !match.isEmpty else { return "" }
        let t = text.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return match }
        let low = t.lowercased()
        let lowM = match.lowercased()
        guard lowM.hasPrefix(low) else { return "" }
        return String(match.dropFirst(t.count))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showLabel && !label.isEmpty {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 4) {
                inlineHintField
                Button {
                    showSuggestions.toggle()
                } label: {
                    Image(systemName: "chevron.down.circle")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(alignment: .topLeading) {
            if showSuggestions && !matches.isEmpty {
                suggestionsDropdown
            }
        }
        .onChange(of: isFocused) { _, focused in
            if !focused {
                commitValue()
                showSuggestions = false
            }
        }
    }

    private var inlineHintField: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.roundedBorder)
            .focused($isFocused)
            .onSubmit { commitAndAdvance() }
            .onExitCommand { showSuggestions = false }
            .overlay(alignment: .leading) {
                if !completionSuffix.isEmpty {
                    HStack(spacing: 0) {
                        Color.clear.frame(width: typedTextWidth + 8)
                        Text(completionSuffix)
                            .foregroundStyle(.secondary)
                            .opacity(0.6)
                            .lineLimit(1)
                            .allowsHitTesting(false)
                    }
                    .padding(.leading, 4)
                }
            }
            .background {
                Text(text.isEmpty ? " " : text)
                    .lineLimit(1)
                    .fixedSize()
                    .hidden()
                    .overlay(GeometryReader { g in Color.clear.preference(key: TextWidthKey.self, value: g.size.width) })
            }
            .onPreferenceChange(TextWidthKey.self) { typedTextWidth = $0 }
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
