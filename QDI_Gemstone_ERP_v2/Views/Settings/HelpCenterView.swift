import SwiftUI

// MARK: - Help Data Models

struct HelpSection: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let articles: [HelpArticle]
}

struct HelpArticle: Identifiable {
    let id = UUID()
    let title: String
    let body: [HelpBlock]
}

enum HelpBlock: Identifiable {
    case paragraph(String)
    case heading(String)
    case tip(String)
    case warning(String)
    case steps([String])
    case keyboardShortcut(key: String, description: String)
    case keyboardShortcutGroup([(key: String, description: String)])

    var id: String {
        switch self {
        case .paragraph(let t): return "p-\(t.prefix(30))"
        case .heading(let t): return "h-\(t)"
        case .tip(let t): return "tip-\(t.prefix(30))"
        case .warning(let t): return "warn-\(t.prefix(30))"
        case .steps(let s): return "steps-\(s.count)"
        case .keyboardShortcut(let k, _): return "key-\(k)"
        case .keyboardShortcutGroup(let items): return "keygroup-\(items.count)"
        }
    }
}

// MARK: - Help Center View

struct HelpCenterView: View {
    @State private var searchText = ""
    @State private var selectedSection: HelpSection?
    @State private var selectedArticle: HelpArticle?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(AppColors.primary)
                Text("Help Center")
                    .font(AppTypography.heading)
                    .foregroundStyle(AppColors.ink)
                Spacer()
                Text("QDI Gemstone ERP")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkSubtle)
                Button("Done") { dismiss() }
                    .buttonStyle(.outline)
            }
            .padding(AppSpacing.hero)

            // Search bar
            GlassSearchField(text: $searchText, placeholder: "Search help articles...")
                .padding(.horizontal, AppSpacing.hero)
                .padding(.bottom, AppSpacing.section)

            // Content
            if searchText.isEmpty && selectedSection == nil {
                sectionGrid
            } else if let section = selectedSection, selectedArticle == nil {
                articleList(for: section)
            } else if let article = selectedArticle {
                articleDetail(for: article)
            } else {
                searchResults
            }
        }
        .frame(minWidth: 750, minHeight: 600)
        .appBackground()
    }

    // MARK: - Section Grid

    private var sectionGrid: some View {
        ScrollView {
            // Quick Start banner
            HStack(spacing: AppSpacing.section) {
                VStack(alignment: .leading, spacing: AppSpacing.compact) {
                    Text("Welcome to QDI Gemstone ERP")
                        .font(AppTypography.subheading)
                        .foregroundStyle(AppColors.ink)
                    Text("Your complete gemstone and diamond inventory management system. Browse the sections below or search for a specific topic.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.inkMuted)
                }
                Spacer()
                Image(systemName: "sparkles")
                    .font(.system(size: 36))
                    .foregroundStyle(AppColors.primary.opacity(AppOpacity.medium))
            }
            .padding(AppSpacing.hero)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(AppColors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                    )
            )
            .padding(.horizontal, AppSpacing.hero)
            .padding(.bottom, AppSpacing.section)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: AppSpacing.section),
                GridItem(.flexible(), spacing: AppSpacing.section)
            ], spacing: AppSpacing.section) {
                ForEach(Self.helpSections) { section in
                    Button {
                        withAnimation(reduceMotion ? nil : AppAnimation.standard) {
                            selectedSection = section
                        }
                    } label: {
                        HStack(spacing: AppSpacing.comfortable) {
                            ZStack {
                                RoundedRectangle(cornerRadius: AppCornerRadius.field, style: .continuous)
                                    .fill(AppColors.primary.opacity(AppOpacity.subtle))
                                    .frame(width: 44, height: 44)
                                Image(systemName: section.icon)
                                    .font(.system(size: 20))
                                    .foregroundStyle(AppColors.primary)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(section.title)
                                    .font(AppTypography.subheading)
                                    .foregroundStyle(AppColors.ink)
                                Text(section.subtitle)
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.inkSubtle)
                                    .lineLimit(2)
                                Text("\(section.articles.count) articles")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.inkMuted)
                                    .padding(.top, 2)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.inkSubtle)
                        }
                        .padding(AppSpacing.section)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(AppColors.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(section.title), \(section.articles.count) articles")
                }
            }
            .padding(.horizontal, AppSpacing.hero)
            .padding(.bottom, AppSpacing.hero)

            // Version footer
            HStack {
                Spacer()
                Text("Version 2.0 • Quality Diajewels Inc.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.inkSubtle)
                Spacer()
            }
            .padding(.bottom, AppSpacing.hero)
        }
    }

    // MARK: - Article List

    private func articleList(for section: HelpSection) -> some View {
        VStack(spacing: 0) {
            // Breadcrumb
            HStack(spacing: AppSpacing.compact) {
                Button {
                    withAnimation(reduceMotion ? nil : AppAnimation.standard) {
                        selectedSection = nil
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("All Topics")
                    }
                    .font(AppTypography.smallValue)
                    .foregroundStyle(AppColors.primary)
                }
                .buttonStyle(.plain)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(AppColors.inkSubtle)

                Text(section.title)
                    .font(AppTypography.smallValue)
                    .foregroundStyle(AppColors.inkMuted)

                Spacer()
            }
            .padding(.horizontal, AppSpacing.hero)
            .padding(.bottom, AppSpacing.section)

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
                    HStack(spacing: AppSpacing.comfortable) {
                        Image(systemName: section.icon)
                            .font(.system(size: 24))
                            .foregroundStyle(AppColors.primary)
                        VStack(alignment: .leading) {
                            Text(section.title)
                                .font(AppTypography.heading)
                                .foregroundStyle(AppColors.ink)
                            Text(section.subtitle)
                                .font(AppTypography.body)
                                .foregroundStyle(AppColors.inkMuted)
                        }
                    }
                    .padding(.horizontal, AppSpacing.hero)
                    .padding(.bottom, AppSpacing.compact)

                    ForEach(section.articles) { article in
                        Button {
                            withAnimation(reduceMotion ? nil : AppAnimation.standard) {
                                selectedArticle = article
                            }
                        } label: {
                            HStack {
                                    Image(systemName: "doc.text")
                                        .foregroundStyle(AppColors.primary)
                                    Text(article.title)
                                        .font(AppTypography.body)
                                        .foregroundStyle(AppColors.ink)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(AppTypography.caption)
                                        .foregroundStyle(AppColors.inkSubtle)
                                }
                                .padding(AppSpacing.section)
                                .background(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(AppColors.cardBackground)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(article.title)
                    }
                }
                .padding(.horizontal, AppSpacing.hero)
                .padding(.bottom, AppSpacing.hero)
            }
        }
    }

    // MARK: - Article Detail

    private func articleDetail(for article: HelpArticle) -> some View {
        VStack(spacing: 0) {
            // Breadcrumb
            HStack(spacing: AppSpacing.compact) {
                Button {
                    withAnimation(reduceMotion ? nil : AppAnimation.standard) {
                        selectedArticle = nil
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text(selectedSection?.title ?? "Back")
                    }
                    .font(AppTypography.smallValue)
                    .foregroundStyle(AppColors.primary)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, AppSpacing.hero)
            .padding(.bottom, AppSpacing.section)

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.section) {
                    Text(article.title)
                        .font(AppTypography.heading)
                        .foregroundStyle(AppColors.ink)
                        .padding(.horizontal, AppSpacing.hero)

                    ForEach(article.body) { block in
                        blockView(block)
                            .padding(.horizontal, AppSpacing.hero)
                    }
                }
                .padding(.bottom, AppSpacing.hero * 2)
            }
        }
    }

    @ViewBuilder
    private func blockView(_ block: HelpBlock) -> some View {
        switch block {
        case .paragraph(let text):
            Text(text)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.inkMuted)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

        case .heading(let text):
            Text(text)
                .font(AppTypography.subheading)
                .foregroundStyle(AppColors.ink)
                .padding(.top, AppSpacing.compact)

        case .tip(let text):
            HStack(alignment: .top, spacing: AppSpacing.comfortable) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                    .font(AppTypography.body)
                Text(text)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.inkMuted)
                    .lineSpacing(3)
            }
            .padding(AppSpacing.section)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.field, style: .continuous)
                    .fill(Color.yellow.opacity(AppOpacity.subtle))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCornerRadius.field, style: .continuous)
                            .strokeBorder(Color.yellow.opacity(AppOpacity.muted), lineWidth: 1)
                    )
            )

        case .warning(let text):
            HStack(alignment: .top, spacing: AppSpacing.comfortable) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(AppTypography.body)
                Text(text)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.inkMuted)
                    .lineSpacing(3)
            }
            .padding(AppSpacing.section)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.field, style: .continuous)
                    .fill(Color.orange.opacity(AppOpacity.subtle))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCornerRadius.field, style: .continuous)
                            .strokeBorder(Color.orange.opacity(AppOpacity.muted), lineWidth: 1)
                    )
            )

        case .steps(let items):
            VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: AppSpacing.comfortable) {
                        ZStack {
                            Circle()
                                .fill(AppColors.primary.opacity(AppOpacity.muted))
                                .frame(width: 26, height: 26)
                            Text("\(index + 1)")
                                .font(AppTypography.smallValue.weight(.semibold))
                                .foregroundStyle(AppColors.primary)
                        }
                        Text(step)
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.inkMuted)
                            .lineSpacing(3)
                    }
                }
            }
            .padding(AppSpacing.section)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.field, style: .continuous)
                    .fill(AppColors.cardElevated.opacity(AppOpacity.strong))
            )

        case .keyboardShortcut(let key, let description):
            HStack {
                Text(key)
                    .font(.system(.body, design: .monospaced).weight(.medium))
                    .foregroundStyle(AppColors.ink)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: AppCornerRadius.small, style: .continuous)
                            .fill(AppColors.cardElevated)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppCornerRadius.small, style: .continuous)
                                    .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                            )
                    )
                Text(description)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.inkMuted)
            }

        case .keyboardShortcutGroup(let items):
            VStack(alignment: .leading, spacing: AppSpacing.compact) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack {
                        Text(item.key)
                            .font(.system(.body, design: .monospaced).weight(.medium))
                            .foregroundStyle(AppColors.ink)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: AppCornerRadius.small, style: .continuous)
                                    .fill(AppColors.cardElevated)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppCornerRadius.small, style: .continuous)
                                            .strokeBorder(AppColors.cardStroke, lineWidth: 1)
                                    )
                            )
                            .frame(minWidth: 100, alignment: .leading)
                        Text(item.description)
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.inkMuted)
                        Spacer()
                    }
                }
            }
            .padding(AppSpacing.section)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.field, style: .continuous)
                    .fill(AppColors.cardElevated.opacity(AppOpacity.strong))
            )
        }
    }

    // MARK: - Search Results

    private var searchResults: some View {
        let query = searchText.lowercased()
        let results = Self.helpSections.flatMap { section in
            section.articles.compactMap { article -> (HelpSection, HelpArticle)? in
                let titleMatch = article.title.lowercased().contains(query)
                let bodyMatch = article.body.contains { block in
                    switch block {
                    case .paragraph(let t), .heading(let t), .tip(let t), .warning(let t):
                        return t.lowercased().contains(query)
                    case .steps(let s):
                        return s.joined().lowercased().contains(query)
                    case .keyboardShortcut(let k, let d):
                        return k.lowercased().contains(query) || d.lowercased().contains(query)
                    case .keyboardShortcutGroup(let items):
                        return items.contains { $0.key.lowercased().contains(query) || $0.description.lowercased().contains(query) }
                    }
                }
                return (titleMatch || bodyMatch) ? (section, article) : nil
            }
        }

        return ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.comfortable) {
                Text("\(results.count) result\(results.count == 1 ? "" : "s") for \"\(searchText)\"")
                    .font(AppTypography.subheading)
                    .foregroundStyle(AppColors.ink)
                    .padding(.horizontal, AppSpacing.hero)

                if results.isEmpty {
                    GlassCard(padding: AppSpacing.hero) {
                        VStack(spacing: AppSpacing.section) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 36))
                                .foregroundStyle(AppColors.inkSubtle)
                            Text("No articles found")
                                .font(AppTypography.subheading)
                                .foregroundStyle(AppColors.ink)
                            Text("Try different keywords or browse the topic sections.")
                                .font(AppTypography.body)
                                .foregroundStyle(AppColors.inkMuted)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, AppSpacing.hero)
                } else {
                    ForEach(results, id: \.1.id) { section, article in
                        Button {
                            withAnimation(reduceMotion ? nil : AppAnimation.standard) {
                                selectedSection = section
                                selectedArticle = article
                            }
                        } label: {
                            GlassCard(padding: AppSpacing.section) {
                                HStack {
                                    Image(systemName: section.icon)
                                        .foregroundStyle(AppColors.primary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(article.title)
                                            .font(AppTypography.body)
                                            .foregroundStyle(AppColors.ink)
                                        Text(section.title)
                                            .font(AppTypography.caption)
                                            .foregroundStyle(AppColors.inkSubtle)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(AppTypography.caption)
                                        .foregroundStyle(AppColors.inkSubtle)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, AppSpacing.hero)
                }
            }
            .padding(.bottom, AppSpacing.hero)
        }
    }
}

// MARK: - Help Content Data

extension HelpCenterView {
    static let helpSections: [HelpSection] = [
        // ─────────────────────────────────────────────
        // 1. GETTING STARTED
        // ─────────────────────────────────────────────
        HelpSection(
            icon: "play.circle.fill",
            title: "Getting Started",
            subtitle: "First-time setup, navigation, and core concepts",
            articles: [
                HelpArticle(title: "Welcome & Overview", body: [
                    .paragraph("QDI Gemstone ERP is a professional inventory management system built specifically for gemstone and diamond dealers. It handles your entire workflow — from stone intake and grading to memos, invoices, and financial reporting."),
                    .heading("Who Is This For?"),
                    .paragraph("The system is designed for independent dealers, small-to-medium trading houses, and operations managers who need a reliable, fast way to track hundreds or thousands of stones across memos, sales, and consignment."),
                    .heading("Core Modules"),
                    .steps([
                        "Dashboard — Overview of your business at a glance: inventory value, open memos, recent activity, and key metrics.",
                        "Inventory — Three dedicated views: Diamonds, Gemstones, and Lots. Each optimized for its stone category with relevant columns and filters.",
                        "Transactions — Memos (consignment) and Invoices (sales). Track every stone from memo out to invoice paid.",
                        "Customers — Your buyer database with contact details, preferences, and lifetime value tracking.",
                        "Accounting & Reports — P&L statements, inventory turnover, customer profitability, AR aging, and margin analysis.",
                        "Scanner & RFID — Tag stones, scan for reconciliation, and process memo returns with your RFID hardware.",
                        "Settings — Company profile, RapNet integration, cloud backup, label printing, and system preferences."
                    ]),
                ]),

                HelpArticle(title: "First-Time Setup", body: [
                    .heading("Initial Configuration"),
                    .paragraph("When you first launch QDI Gemstone ERP, you'll see the onboarding screen. Complete these steps to get started:"),
                    .steps([
                        "Enter your company name and logo. This appears on all memos, invoices, and PDF exports.",
                        "Set your default currency. You can use multiple currencies per-stone, but the default is used for new entries.",
                        "Configure your company address and contact details for document headers.",
                        "Optionally connect your RFID reader (Settings → Scanner) and Zebra label printer (Settings → Labels).",
                        "If you use RapNet, enter your API credentials in Settings → RapNet Integration."
                    ]),
                    .tip("You can change all of these settings later from the Settings panel (⌘ ,)."),
                ]),

                HelpArticle(title: "Navigating the App", body: [
                    .heading("Sidebar Navigation"),
                    .paragraph("The sidebar on the left organizes all modules into groups: Get Started, Sales, Accounting, Inventory, and System. Click any item to switch views. The sidebar can be toggled with ⌥⌘S."),
                    .heading("Keyboard Shortcuts"),
                    .paragraph("Power users can navigate entirely by keyboard:"),
                    .keyboardShortcutGroup([
                        (key: "⌘1", description: "Dashboard"),
                        (key: "⌘2", description: "Memos"),
                        (key: "⌘3", description: "Invoices"),
                        (key: "⌘4", description: "Customers"),
                        (key: "⌘5", description: "Diamonds"),
                        (key: "⌘6", description: "Gemstones"),
                        (key: "⌘7", description: "Lots"),
                        (key: "⌘8", description: "Sold"),
                        (key: "⌘9", description: "Quick Intake"),
                        (key: "⌘N", description: "New Item (context-dependent)"),
                        (key: "⇧⌘M", description: "New Memo"),
                        (key: "⌘I", description: "New Invoice"),
                        (key: "⌥⌘S", description: "Toggle Sidebar"),
                        (key: "⌘,", description: "Settings"),
                        (key: "⌘F", description: "Focus Search (in list views)"),
                        (key: "Escape", description: "Close current sheet or panel"),
                    ]),
                    .heading("Unsaved Changes Protection"),
                    .paragraph("If you navigate away from a form with unsaved changes, a confirmation dialog will ask whether to discard or keep editing. This prevents accidental data loss."),
                ]),
            ]
        ),

        // ─────────────────────────────────────────────
        // 2. INVENTORY MANAGEMENT
        // ─────────────────────────────────────────────
        HelpSection(
            icon: "sparkle",
            title: "Inventory Management",
            subtitle: "Adding, editing, filtering, and organizing your stones",
            articles: [
                HelpArticle(title: "Diamonds Inventory", body: [
                    .paragraph("The Diamonds view shows all stones where Stone Type is Diamond. It displays diamond-specific columns: Cut, Polish, Symmetry, Fluorescence, and Rapaport pricing fields."),
                    .heading("Diamond-Specific Fields"),
                    .steps([
                        "Cut Grade — Excellent, Very Good, Good, Fair, Poor. Critical for diamond valuation.",
                        "Polish — Surface finish quality. Same grade scale as cut.",
                        "Symmetry — Facet alignment precision. Affects brilliance and fire.",
                        "Fluorescence — UV reaction intensity and color. Strong fluorescence can affect value.",
                        "Rap Price ($/ct) — Your asking price per carat on the Rapaport Price List.",
                        "Rap Discount (%) — Percentage below (negative) or above (positive) the Rap list price."
                    ]),
                    .heading("Filtering & Search"),
                    .paragraph("Use the filter pills at the top to narrow by shape, color, clarity, carat range, and status. Saved filter presets let you bookmark common searches like 'Round D-F VS+ 1ct+'. Type in the search bar or press ⌘F to find stones by SKU, cert number, or any field."),
                    .tip("The margin column shows your profit percentage on each stone. Bulk-select stones and use '% Price Adjust' to raise or lower prices across your selection."),
                ]),

                HelpArticle(title: "Gemstones Inventory", body: [
                    .paragraph("The Gemstones view shows all non-diamond, non-lot stones. It emphasizes colored-stone fields: Origin, Treatment, and stone type variety."),
                    .heading("Treatment Tracking"),
                    .paragraph("Treatment is a first-class field for colored stones. Common treatments include heating (sapphires, rubies), oiling (emeralds), and irradiation. Treatment status significantly affects value and must be disclosed to buyers."),
                    .heading("Origin"),
                    .paragraph("Geographic origin can dramatically affect gemstone prices. A Burmese ruby commands a premium over a Thai ruby of identical specs. Always record origin when known — it's a key selling point."),
                    .tip("Treatment appears in Quick Entry, CSV import, and filter pills. Use it to quickly find untreated stones for premium buyers."),
                ]),

                HelpArticle(title: "Lots", body: [
                    .paragraph("Lots are groups of similar stones sold by total carat weight rather than individually. The Lots view adds a Stone Type column so you can manage diamond lots and colored stone lots in one place."),
                    .heading("Lot Transactions"),
                    .paragraph("When you sell part of a lot, create a Lot Transaction to record the split — the system tracks remaining carats and adjusts the effective per-carat cost automatically."),
                    .warning("Lot values are calculated from effective remaining carats. If you edit a lot's weight directly instead of using transactions, the per-carat pricing may become inaccurate."),
                ]),

                HelpArticle(title: "Quick Intake & Quick Entry", body: [
                    .heading("Quick Intake"),
                    .paragraph("Quick Intake (⌘9) is the full stone entry form. Use it when you're adding a single stone with complete details — all grading fields, pricing, certifications, and RFID tagging are available here."),
                    .heading("Quick Entry"),
                    .paragraph("Quick Entry is the bulk intake tool for adding multiple stones rapidly. It provides a streamlined grid with only the essential fields. All 20 stone types are available in the picker. Ideal for processing a new parcel where you need speed over detail."),
                    .steps([
                        "Select stone type from the picker (Diamond, Ruby, Sapphire, Emerald, etc.)",
                        "Enter weight, shape, and color/clarity basics.",
                        "Set cost price and sell price.",
                        "Hit Enter or click Add — the form clears for the next stone.",
                        "Review and fill in remaining details later from the inventory view."
                    ]),
                    .tip("Quick Entry supports all 20 stone types including lesser-traded varieties like Alexandrite, Tanzanite, Paraíba, and Spinel."),
                ]),

                HelpArticle(title: "Bulk Operations", body: [
                    .heading("Bulk Selection"),
                    .paragraph("In any inventory view, hold ⌘ and click to select multiple stones, or use ⇧-click for range selection. Selected stones highlight with the accent color."),
                    .heading("Bulk Price Adjust"),
                    .paragraph("With multiple stones selected, use the '% Price Adjust' action to raise or lower all selected stones' sell prices by a percentage. This is useful when adjusting prices for a market shift or a specific buyer's negotiation."),
                    .heading("Bulk Edit"),
                    .paragraph("Edit shared fields (status, treatment, origin, salesperson) across multiple selected stones at once. An undo toast appears for 5 seconds after any bulk edit, letting you reverse the change instantly."),
                    .warning("Bulk operations cannot be undone after the 5-second undo window closes. Double-check your selection before confirming large batch changes."),
                ]),
            ]
        ),

        // ─────────────────────────────────────────────
        // 3. MEMOS & INVOICES
        // ─────────────────────────────────────────────
        HelpSection(
            icon: "doc.text.fill",
            title: "Memos & Invoices",
            subtitle: "Consignment, sales, and document management",
            articles: [
                HelpArticle(title: "Understanding Memos", body: [
                    .paragraph("A memo (also called a consignment note) is a document that records stones sent to a buyer for inspection. The seller retains ownership until the buyer decides to purchase or return the stones."),
                    .heading("Memo Lifecycle"),
                    .steps([
                        "Create a new memo (⇧⌘M) and select a customer.",
                        "Add line items — search for stones by SKU or scan RFID tags.",
                        "Assign a salesperson and set terms/notes.",
                        "Send the memo — stones automatically change status to 'On Memo'.",
                        "When stones come back, process returns (individually or via RFID scan).",
                        "Convert kept stones to an invoice for final sale."
                    ]),
                    .heading("Memo Aging"),
                    .paragraph("The system tracks how long each memo has been open. Aging alerts use a 4-tier color system: green (0-14 days), yellow (15-30 days), orange (31-60 days), and red (60+ days). Use the AR module to manage overdue memos."),
                    .tip("Use the RFID Memo Return scanner to process returns instantly — scan a stone and the system identifies which memo it belongs to and offers a one-tap return."),
                ]),

                HelpArticle(title: "Creating Invoices", body: [
                    .paragraph("Invoices are created when a buyer commits to purchasing stones, either from a memo or directly."),
                    .heading("From a Memo"),
                    .paragraph("Open the memo and mark the stones the buyer wants to keep. Click 'Convert to Invoice' — the system creates an invoice with those line items pre-filled, linking it back to the originating memo."),
                    .heading("Direct Invoice"),
                    .paragraph("Press ⌘I to create a new invoice without a prior memo. Add the customer, line items, and pricing. The system generates a reference number automatically."),
                    .heading("Invoice Fields"),
                    .steps([
                        "Discount — A flat amount deducted from the subtotal.",
                        "Tax Rate — Percentage applied after discount. Computed tax amount shown automatically.",
                        "Terms — Payment terms (Net 30, COD, etc.).",
                        "Salesperson — The rep who closed the deal.",
                        "Notes — Internal or customer-facing notes printed on the document."
                    ]),
                ]),

                HelpArticle(title: "PDF Export & Printing", body: [
                    .paragraph("Both memos and invoices can be exported as professional PDF documents suitable for emailing to customers or printing."),
                    .heading("PDF Features"),
                    .steps([
                        "Company logo and address in the header.",
                        "Full line item table with stone details, per-carat and total prices.",
                        "Discount and tax rows when applicable.",
                        "UTF-8 support for international characters.",
                        "Page breaks for long documents.",
                        "Print-safe colors that reproduce correctly on paper."
                    ]),
                    .tip("PDF generation uses your company details from Settings. Make sure your company name, address, and logo are configured before sending documents to customers."),
                ]),
            ]
        ),

        // ─────────────────────────────────────────────
        // 4. CUSTOMERS
        // ─────────────────────────────────────────────
        HelpSection(
            icon: "person.2.fill",
            title: "Customers",
            subtitle: "Managing your buyer database and relationships",
            articles: [
                HelpArticle(title: "Customer Management", body: [
                    .paragraph("The Customers module stores all your buyer information — contact details, company name, and address. Every memo and invoice is linked to a customer, building a complete relationship history."),
                    .heading("Customer Fields"),
                    .steps([
                        "First Name & Last Name — The buyer's personal name.",
                        "Company — Their trading company or business name.",
                        "Email & Phone — Contact information for communications.",
                        "Address, City, Country, ZIP — Full postal address for shipping and invoices.",
                        "Notes — Private notes about the buyer (preferences, payment history, special terms)."
                    ]),
                    .heading("Searchable Combobox"),
                    .paragraph("When adding a customer to a memo or invoice, the searchable combobox lets you quickly find existing customers by typing any part of their name or company. This scales to 500+ customers without performance issues."),
                ]),

                HelpArticle(title: "Customer Lifetime Value", body: [
                    .paragraph("Each customer's profile shows their Lifetime Value (CLV) — the total revenue they've generated across all invoices. This helps you identify your most valuable buyers and prioritize relationships."),
                    .heading("Profitability Analysis"),
                    .paragraph("The Reports → Customer Profitability view goes deeper, showing revenue, cost of goods, gross profit, margin percentage, transaction count, and average order value per customer. Use this to identify your most and least profitable relationships."),
                    .tip("High revenue doesn't always mean high profit. A customer buying at thin margins may generate less profit than a smaller buyer paying full markup. Check the margin column, not just the total."),
                ]),
            ]
        ),

        // ─────────────────────────────────────────────
        // 5. REPORTING & ANALYTICS
        // ─────────────────────────────────────────────
        HelpSection(
            icon: "chart.bar.xaxis",
            title: "Reporting & Analytics",
            subtitle: "P&L, turnover, margins, and financial insights",
            articles: [
                HelpArticle(title: "Profit & Loss Report", body: [
                    .paragraph("The P&L report summarizes your financial performance over a selected period. It calculates revenue from invoices, cost of goods from stone cost prices, and derives your gross profit and margin percentage."),
                    .heading("Breakdown by Stone Type"),
                    .paragraph("The report breaks down P&L by stone type — Diamonds vs. each colored stone category. This reveals which categories drive your profit and which may need pricing adjustments."),
                    .heading("Date Ranges"),
                    .paragraph("Choose from preset ranges (This Month, Last Month, This Quarter, This Year) or set a custom date range. The report recalculates instantly when you change the period."),
                    .tip("Export the P&L as PDF for your accountant or as CSV to analyze in Excel. Use the Export button in the top-right corner of the report view."),
                ]),

                HelpArticle(title: "Inventory Turnover", body: [
                    .paragraph("Inventory turnover measures how quickly your stock sells. A higher turnover rate means your capital isn't sitting idle in unsold stones."),
                    .heading("How It's Calculated"),
                    .paragraph("Turnover Rate = Cost of Goods Sold ÷ Average Inventory Value. The report shows your current inventory count and value, units sold in the period, and the resulting turnover rate."),
                    .heading("Aging Buckets"),
                    .paragraph("Stones are grouped by how long they've been in inventory: 0–30 days, 31–60, 61–90, 91–180, and 180+ days. A bar chart visualizes the distribution. Below the chart, a 'Slow Movers' list highlights stones sitting longer than 90 days — these may need price reductions or targeted memo outreach."),
                    .warning("Stones sitting over 180 days tie up capital and may have shifted in market value. Review slow movers monthly and consider repricing or memo-ing to active buyers."),
                ]),

                HelpArticle(title: "Customer Profitability", body: [
                    .paragraph("This report ranks all customers by profitability. For each buyer, it shows total revenue, total cost, gross profit, margin percentage, number of transactions, and average order value."),
                    .heading("Top & Bottom Performers"),
                    .paragraph("The top 10 most profitable customers are highlighted in green. The bottom 10 are highlighted to flag relationships that may need renegotiation or reassessment. Click any customer to see their full transaction history."),
                ]),

                HelpArticle(title: "Margin Analysis", body: [
                    .paragraph("Margin analysis provides three views into your pricing performance:"),
                    .steps([
                        "Monthly Margin Trend — A line chart showing your average margin over the last 12 months. Spot seasonal patterns and pricing drift.",
                        "Margin by Stone Type — A horizontal bar chart comparing average margin across diamond and each gemstone category. Identify which categories deliver the best return.",
                        "Margin Distribution — A histogram showing what percentage of stones sold at various margin brackets (<10%, 10–20%, 20–30%, 30%+). Healthy businesses show a bell curve centered on their target margin."
                    ]),
                ]),
            ]
        ),

        // ─────────────────────────────────────────────
        // 6. ACCOUNTS RECEIVABLE
        // ─────────────────────────────────────────────
        HelpSection(
            icon: "banknote",
            title: "Accounts Receivable",
            subtitle: "Outstanding balances, payment tracking, and aging",
            articles: [
                HelpArticle(title: "AR Dashboard", body: [
                    .paragraph("The Accounts Receivable dashboard gives you an instant view of all money owed to you. The hero card shows total outstanding AR, with a breakdown by aging bucket: Current, 30 days, 60 days, and 90+ days overdue."),
                    .heading("Quick Stats"),
                    .paragraph("At a glance, see the number of overdue invoices, your largest outstanding balance, and the oldest unpaid invoice. These help you prioritize collection efforts."),
                    .heading("Bulk Reminders"),
                    .paragraph("Use the 'Send Reminders' action to flag overdue customers for follow-up. The system tracks when reminders were sent and won't re-flag within 7 days to avoid harassing good customers."),
                ]),

                HelpArticle(title: "Aging View", body: [
                    .paragraph("The aging view shows every unpaid invoice in a color-coded table: green for current, yellow for 30 days, orange for 60 days, and red for 90+ days past due."),
                    .heading("Partial Payments"),
                    .paragraph("Invoices with partial payments show a progress bar indicating how much has been paid vs. the total. Click any invoice to see its full payment history and record additional payments."),
                    .heading("Filtering"),
                    .paragraph("Filter the aging view by bucket (show only 90+ day invoices), by customer, or by date range. This helps you focus collection calls on the most overdue accounts."),
                ]),

                HelpArticle(title: "Recording Payments", body: [
                    .heading("How to Record a Payment"),
                    .steps([
                        "Navigate to the customer's balance view or click an invoice in the aging table.",
                        "Click 'Record Payment'.",
                        "Enter the payment amount, method (wire, check, cash, credit card, other), and reference number.",
                        "The system allocates the payment to the selected invoice(s). If the payment covers multiple invoices, it applies to the oldest first by default.",
                        "The invoice status updates automatically — partially paid, or closed if fully settled."
                    ]),
                    .tip("Always record the bank reference number or check number. This makes reconciliation with your bank statements much faster."),
                ]),
            ]
        ),

        // ─────────────────────────────────────────────
        // 7. RFID & SCANNING
        // ─────────────────────────────────────────────
        HelpSection(
            icon: "antenna.radiowaves.left.and.right",
            title: "RFID & Scanning",
            subtitle: "Tagging, scanning, reconciliation, and memo returns",
            articles: [
                HelpArticle(title: "RFID Setup", body: [
                    .paragraph("QDI Gemstone ERP supports USB-serial RFID readers (tested with Kcosit/Silion readers at 115,200 baud) for stone tagging and scanning operations."),
                    .heading("Hardware Connection"),
                    .steps([
                        "Plug your USB RFID reader into your Mac.",
                        "Go to Settings → Scanner and select the serial port (usually /dev/tty.usbserial-*).",
                        "Set baud rate to 115200 (default for supported readers).",
                        "Click 'Test Connection' to verify the reader responds.",
                        "The scanner icon in the sidebar will light up when connected."
                    ]),
                    .warning("If the reader doesn't appear in the port list, check System Settings → Privacy & Security → Serial Port and ensure QDI Gemstone ERP has permission."),
                ]),

                HelpArticle(title: "Tagging Stones", body: [
                    .paragraph("Each stone can be assigned an RFID tag for instant identification. Tags store the EPC (Electronic Product Code) and optional TID (Tag Identifier)."),
                    .heading("Assigning Tags"),
                    .steps([
                        "Open the Scanner view from the sidebar.",
                        "Place the RFID-tagged envelope or capsule near the reader.",
                        "When the tag is read, the system checks if it's already assigned.",
                        "If unassigned, a sheet appears to link it to a stone by SKU.",
                        "The tag association is permanent unless manually removed in the stone's detail view."
                    ]),
                    .tip("For high-value stones, consider using tamper-evident RFID tags. The system logs the complete lifecycle: when the tag was assigned, read, and if it was ever detached or replaced."),
                ]),

                HelpArticle(title: "Inventory Reconciliation", body: [
                    .paragraph("Reconciliation lets you physically verify your inventory by batch-scanning all RFID-tagged stones in a location (safe, display case, vault) and comparing against your database records."),
                    .heading("Running a Reconciliation"),
                    .steps([
                        "Open the Reconcile view from the sidebar.",
                        "Click 'Start Reconciliation' — the reader enters continuous scan mode.",
                        "Walk the reader past each tagged stone. The counter updates in real-time as tags are read.",
                        "Click 'Stop & Reconcile' when you've scanned everything.",
                        "The system compares scanned tags against the database and shows three categories."
                    ]),
                    .heading("Result Categories"),
                    .steps([
                        "✅ Matched — Stones found both in the database and in the scan. Everything is accounted for.",
                        "⚠️ Missing — Stones in the database but NOT scanned. These need investigation — wrong location? On memo? Lost?",
                        "❓ Unknown — Tags scanned but not in the database. May be unassigned tags or tags from another system."
                    ]),
                    .paragraph("Export the discrepancy report as PDF for record-keeping. Each reconciliation event is saved to the history log."),
                ]),

                HelpArticle(title: "RFID Memo Returns", body: [
                    .paragraph("The fastest way to process memo returns: scan the returning stone's RFID tag and the system identifies which memo it belongs to."),
                    .heading("Single Return"),
                    .paragraph("Scan one tag → the system shows the memo details (customer, date, terms). Confirm the return and the stone automatically moves from 'On Memo' back to 'Available', with a history event logged."),
                    .heading("Batch Return"),
                    .paragraph("Scan multiple tags → the system queues all identified memo stones. Review the batch list and confirm all returns at once. Ideal for processing a bag of returned stones."),
                    .tip("If a scanned stone isn't on any memo, the system shows its current status. No accidental double-returns or status confusion."),
                ]),
            ]
        ),

        // ─────────────────────────────────────────────
        // 8. LABEL PRINTING
        // ─────────────────────────────────────────────
        HelpSection(
            icon: "printer.fill",
            title: "Label Printing",
            subtitle: "Stone labels with barcodes for Zebra printers",
            articles: [
                HelpArticle(title: "Printer Setup", body: [
                    .paragraph("QDI Gemstone ERP generates ZPL (Zebra Programming Language) labels for Zebra ZD611R printers and compatible models. Labels are sent over TCP to the printer."),
                    .heading("Configuration"),
                    .steps([
                        "Go to Settings → Labels.",
                        "Enter the printer's IP address and port (default: localhost:9100 for USB-connected, or the printer's network IP).",
                        "Click 'Test Print' to send a sample label.",
                        "Select your preferred template (Standard, Rapaport, or Minimal)."
                    ]),
                ]),

                HelpArticle(title: "Label Templates", body: [
                    .heading("Standard Template"),
                    .paragraph("Includes SKU, stone type, shape, carat weight, color, clarity, price, and cert number with a Code 128 barcode. Best for general use."),
                    .heading("Rapaport Template"),
                    .paragraph("Industry-standard format matching Rapaport parcel label conventions. Optimized for diamond trade shows and B2B exchanges where buyers expect a specific layout."),
                    .heading("Minimal Template"),
                    .paragraph("Just the SKU, carat weight, and price with a barcode. Use for internal tagging where full details aren't needed on the label — the barcode links back to the complete record."),
                    .paragraph("All templates are formatted for 2\" × 1\" standard jewelry labels. The live preview in Settings shows exactly what will print."),
                ]),
            ]
        ),

        // ─────────────────────────────────────────────
        // 9. RAPNET INTEGRATION
        // ─────────────────────────────────────────────
        HelpSection(
            icon: "globe",
            title: "RapNet Integration",
            subtitle: "Sync your diamond inventory with the Rapaport network",
            articles: [
                HelpArticle(title: "Connecting to RapNet", body: [
                    .paragraph("RapNet is the world's largest diamond trading network. QDI Gemstone ERP can upload your available diamond inventory and pull current Rapaport price sheets."),
                    .heading("Setup"),
                    .steps([
                        "Go to Settings → RapNet Integration.",
                        "Enter your RapNet username and password.",
                        "Click 'Test Connection' to verify your credentials.",
                        "Once connected, you'll see your account status and last sync time."
                    ]),
                    .warning("RapNet credentials are stored locally on your Mac with Data Protection encryption. They are never transmitted to any third party — only to RapNet's API servers directly."),
                ]),

                HelpArticle(title: "Uploading Inventory", body: [
                    .paragraph("The sync process uploads all diamonds with 'Available' status to RapNet. Stones on memo, sold, or in other statuses are excluded."),
                    .heading("Manual Sync"),
                    .paragraph("Click 'Sync Now' in Settings → RapNet. The system generates a CSV of your available diamonds and uploads it. You'll see a progress indicator and the result (success or error details)."),
                    .heading("Auto-Sync"),
                    .paragraph("Enable the auto-sync toggle to upload automatically every 4 hours. The sync log shows the last 10 sync events with timestamps and status."),
                    .tip("After a sync, check the Diamonds inventory view — each stone shows a sync status badge (synced, pending, or error) so you know exactly what's live on RapNet."),
                ]),

                HelpArticle(title: "Price Sheet Updates", body: [
                    .paragraph("Pull the current Rapaport price sheet to automatically update Rap prices on your diamonds. This keeps your pricing competitive with the weekly list changes."),
                    .paragraph("The price pull matches stones by shape, carat range, color, and clarity — then updates the rapNetPrice field. Your actual sell price is independent, so you maintain full control over your markup/discount."),
                ]),
            ]
        ),

        // ─────────────────────────────────────────────
        // 10. BACKUP & DATA SAFETY
        // ─────────────────────────────────────────────
        HelpSection(
            icon: "shield.checkmark.fill",
            title: "Backup & Data Safety",
            subtitle: "Local backups, cloud backup, encryption, and disaster recovery",
            articles: [
                HelpArticle(title: "Local Backup", body: [
                    .paragraph("QDI Gemstone ERP automatically creates a local backup every 24 hours via the BackupScheduler. You can also create manual backups at any time from Settings → Backup & Restore."),
                    .heading("What's Backed Up"),
                    .paragraph("Everything: all stones, customers, memos, invoices, payments, lot transactions, RFID tag assignments, and settings. The backup is a complete snapshot of your database."),
                    .heading("Restore"),
                    .paragraph("To restore from a local backup, go to Settings → Backup & Restore, select a backup file, and confirm. The current database is replaced with the backup. A confirmation dialog warns you before proceeding."),
                    .warning("Restoring from a backup replaces ALL current data. Any changes made after the backup date will be lost. Always create a fresh backup before restoring an older one."),
                ]),

                HelpArticle(title: "Cloud Backup (iCloud)", body: [
                    .paragraph("Cloud backup encrypts your entire database and stores it in your iCloud Drive. This protects against hardware failure, theft, or disaster — your data is recoverable from any Mac signed into the same Apple ID."),
                    .heading("How It Works"),
                    .steps([
                        "Enable cloud backup in Settings → Cloud Backup.",
                        "The system generates an AES-256-GCM encryption key and stores it in your Mac's Keychain.",
                        "Your database is exported, encrypted, compressed, and uploaded to iCloud Drive.",
                        "A manifest records the backup date, device name, stone count, and file size.",
                        "Auto-backup runs daily at 2 AM if any data has changed since the last backup."
                    ]),
                    .heading("Restoring from Cloud"),
                    .paragraph("The cloud backup settings view lists all available backups across your devices (with device name, date, size, and stone count). Select one and click 'Restore'. The system downloads, decrypts, validates integrity, and replaces the local store."),
                    .warning("The encryption key is stored in your Mac's Keychain and is NOT included in the backup file. If you lose access to your Keychain (e.g., new Mac without migration), cloud backups cannot be decrypted. Consider keeping a record of your Keychain in a secure location."),
                ]),

                HelpArticle(title: "Data Store Location", body: [
                    .paragraph("Your database file is stored at:"),
                    .paragraph("~/Library/Application Support/QDI_GemstoneERP/QDIGemstoneERP_v2.store"),
                    .paragraph("This is a SwiftData (SQLite-based) file. Do not edit it directly — always use the app's backup/restore features."),
                    .heading("Migration Safety"),
                    .paragraph("When the app updates with schema changes, SwiftData performs automatic lightweight migration. If migration fails, the app launches with an in-memory database and shows an alert with options to retry or reset. No data is silently deleted."),
                    .tip("If you see the migration failure alert, try quitting and relaunching first. Most migration issues resolve on a clean launch. If the problem persists, restore from your most recent backup."),
                ]),
            ]
        ),

        // ─────────────────────────────────────────────
        // 11. SETTINGS & PREFERENCES
        // ─────────────────────────────────────────────
        HelpSection(
            icon: "gearshape.fill",
            title: "Settings & Preferences",
            subtitle: "Company profile, appearance, and system configuration",
            articles: [
                HelpArticle(title: "Company Settings", body: [
                    .paragraph("Configure your company identity that appears on all documents:"),
                    .steps([
                        "Company Name — Printed at the top of every memo and invoice.",
                        "Company Logo — Drag and drop or click to upload. Appears in PDF document headers.",
                        "Address — Your business address for document footers.",
                        "Contact Details — Phone and email for customer communications."
                    ]),
                    .tip("Keep your logo under 500KB for optimal PDF generation performance. The system accepts PNG and JPEG formats."),
                ]),

                HelpArticle(title: "Appearance", body: [
                    .paragraph("QDI Gemstone ERP uses a dark glass navy theme optimized for long working sessions. You can choose between:"),
                    .steps([
                        "Dark Mode (default) — Deep navy backgrounds with cyan accents. Easiest on the eyes for extended use.",
                        "Light Mode — Light backgrounds with the same accent colors. Better for brightly-lit environments.",
                        "System — Follows your macOS appearance setting, switching automatically."
                    ]),
                ]),

                HelpArticle(title: "REST API", body: [
                    .heading("Embedded API Server"),
                    .paragraph("QDI Gemstone ERP runs a local REST API on port 8847 for external integrations. This allows other tools, scripts, or automation systems to read and write data."),
                    .heading("Available Endpoints"),
                    .steps([
                        "GET /api/inventory — Search and list stones with filters.",
                        "GET /api/dashboard — Business summary metrics.",
                        "GET /api/memos — List memos with status filters.",
                        "GET /api/invoices — List invoices with status filters.",
                        "GET /api/customers — Customer directory.",
                        "GET /api/rfid — RFID tag operations.",
                        "GET /api/system — Health check and version info."
                    ]),
                    .paragraph("All endpoints require a Bearer token for authentication. The default development token is set in the app's startup code. For production use, change the token in Settings."),
                    .warning("The API listens only on localhost (127.0.0.1) by default. It is NOT exposed to your network. If you need remote access, configure a secure reverse proxy."),
                ]),
            ]
        ),

        // ─────────────────────────────────────────────
        // 12. GLOSSARY & REFERENCE
        // ─────────────────────────────────────────────
        HelpSection(
            icon: "book.fill",
            title: "Glossary & Reference",
            subtitle: "Industry terms, grading scales, and quick reference",
            articles: [
                HelpArticle(title: "Gemstone Glossary", body: [
                    .paragraph("Access the full gemstone glossary from Help → Gemstone Glossary in the menu bar, or from the (?) icons throughout the app. The glossary covers 30+ industry terms with clear definitions."),
                    .paragraph("Key terms include: Carat, Clarity, Color, Cut Grade, Fluorescence, Treatment, Origin, Memo, Parcel, Melee, Lot, Rapaport, Rap Discount, Polish, Symmetry, and more."),
                ]),

                HelpArticle(title: "Diamond Grading Reference", body: [
                    .heading("The 4Cs"),
                    .steps([
                        "Carat — Weight. 1 ct = 0.2 grams. Price per carat increases exponentially at magic sizes (0.50, 1.00, 1.50, 2.00).",
                        "Color — D (colorless) through Z (light yellow). D-F: colorless, G-J: near colorless, K-M: faint, N-R: very light, S-Z: light.",
                        "Clarity — FL, IF, VVS1, VVS2, VS1, VS2, SI1, SI2, I1, I2, I3. FL/IF are extremely rare; VS2+ is 'eye clean' for most shapes.",
                        "Cut — Excellent, Very Good, Good, Fair, Poor. Affects brilliance, fire, and scintillation. Only graded for round brilliants by GIA."
                    ]),
                    .heading("Fluorescence"),
                    .paragraph("None, Faint, Medium, Strong, Very Strong. Strong blue fluorescence can make D-F diamonds appear hazy in sunlight but can make I-K diamonds face up whiter. Market discounts vary by region."),
                ]),

                HelpArticle(title: "Colored Stone Grading", body: [
                    .heading("Color Description"),
                    .paragraph("Unlike diamonds, colored stones are described by hue, tone, and saturation rather than a letter grade. Example: 'Vivid medium-dark slightly purplish red' for a fine ruby."),
                    .heading("Common Treatments"),
                    .steps([
                        "Heat Treatment — Standard for sapphires and rubies. Improves color and clarity. Must be disclosed.",
                        "Oiling — Standard for emeralds. Cedar oil fills surface-reaching fractures. Ranges from minor to significant.",
                        "Irradiation — Used for topaz (blue), tourmaline, and some diamonds. Permanent color change.",
                        "Diffusion — Beryllium diffusion in sapphires creates vivid orange/yellow. Requires disclosure.",
                        "No Treatment — Untreated stones command significant premiums, especially for sapphires and rubies."
                    ]),
                ]),
            ]
        ),

        // ─────────────────────────────────────────────
        // KEYBOARD SHORTCUTS
        // ─────────────────────────────────────────────
        HelpSection(
            icon: "keyboard.fill",
            title: "Keyboard Shortcuts",
            subtitle: "Navigate, create, and manage with keyboard shortcuts",
            articles: [
                HelpArticle(title: "Navigation Shortcuts", body: [
                    .heading("Sidebar Navigation"),
                    .paragraph("Quickly jump between main sections using ⌘ + number keys:"),
                    .keyboardShortcutGroup([
                        (key: "⌘1", description: "Dashboard"),
                        (key: "⌘2", description: "Memos"),
                        (key: "⌘3", description: "Invoices"),
                        (key: "⌘4", description: "Customers"),
                        (key: "⌘5", description: "Diamonds"),
                        (key: "⌘6", description: "Gemstones"),
                        (key: "⌘7", description: "Lots"),
                        (key: "⌘8", description: "Sold"),
                        (key: "⌘9", description: "Quick Intake"),
                    ]),
                    .tip("These shortcuts work from any screen and respect the unsaved-changes guard."),
                ]),

                HelpArticle(title: "Creating & Editing", body: [
                    .heading("New Items"),
                    .paragraph("Context-aware creation adapts to your current view:"),
                    .keyboardShortcutGroup([
                        (key: "⌘N", description: "New Item (context-dependent)"),
                        (key: "⇧⌘N", description: "Quick Intake — jump straight to the intake form"),
                        (key: "⇧⌘M", description: "New Memo"),
                        (key: "⌘I", description: "New Invoice"),
                    ]),
                    .heading("Search & Filter"),
                    .keyboardShortcutGroup([
                        (key: "⌘F", description: "Focus the search / filter field"),
                        (key: "Escape", description: "Close panel, deselect, or dismiss sheet"),
                    ]),
                ]),

                HelpArticle(title: "Data & Export", body: [
                    .heading("Data Management"),
                    .keyboardShortcutGroup([
                        (key: "⌘R", description: "Refresh data"),
                        (key: "⌘E", description: "Export current view"),
                        (key: "⌘P", description: "Print current view"),
                        (key: "⌘⇧S", description: "Cloud Backup"),
                    ]),
                    .heading("Workflow Shortcuts"),
                    .keyboardShortcutGroup([
                        (key: "⌘⇧R", description: "Review Queue"),
                        (key: "⌘⇧C", description: "Reconcile"),
                        (key: "⌘⇧A", description: "Aging Report"),
                    ]),
                ]),

                HelpArticle(title: "System & Help", body: [
                    .heading("Application"),
                    .keyboardShortcutGroup([
                        (key: "⌘,", description: "Open Settings"),
                        (key: "⌘?", description: "Open Help Center"),
                        (key: "⌘⌥S", description: "Toggle Sidebar"),
                    ]),
                    .tip("Most shortcuts are also available from the menu bar. Look for the ⌘ symbols next to each menu item."),
                ]),
            ]
        ),
    ]
}
