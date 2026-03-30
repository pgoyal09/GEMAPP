import SwiftUI

// MARK: - Panel Selection

enum DashboardPanelItem {
    case none, addStone, newMemo, newInvoice
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Color.white.opacity(0.50))
            .tracking(1.5)
    }
}

// MARK: - Status Pill

struct StatusPill: View {
    let label: String
    let color: Color
    var onReconnect: () -> Void

    var body: some View {
        GlassCard(padding: 14, cornerRadius: 12) {
            HStack {
                AppStatusBadge(title: label, tone: tone(for: label))
                Spacer()
                Button("Reconnect", action: onReconnect)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.primary)
                    .buttonStyle(.plain)
            }
        }
    }

    private func tone(for label: String) -> AppStatusBadge.Tone {
        let v = label.lowercased()
        if v.contains("scan") || v.contains("connect") { return .success }
        if v.contains("initial") || v.contains("connect") { return .warning }
        if v.contains("error") || v.contains("disconnect") { return .danger }
        return .neutral
    }
}

// MARK: - App Card

struct AppCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        GlassCard(padding: AppSpacing.m) {
            content()
        }
    }
}

// MARK: - Dashboard Action Card

struct DashboardActionCard: View {
    let title: String
    var subtitle: String? = nil
    let icon: String
    var gradient: String = "cyan-blue"
    let action: () -> Void

    private var gradientColors: LinearGradient {
        switch gradient {
        case "cyan-blue":    return LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "emerald-teal": return LinearGradient(colors: [Color(red: 0.20, green: 0.83, blue: 0.60), .teal], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "violet-purple": return LinearGradient(colors: [Color(red: 0.55, green: 0.36, blue: 0.97), .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "amber-orange": return LinearGradient(colors: [Color(red: 0.98, green: 0.75, blue: 0.14), .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "rose-pink":    return LinearGradient(colors: [Color(red: 0.96, green: 0.45, blue: 0.71), .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "teal-cyan":    return LinearGradient(colors: [.teal, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "blue-indigo":  return LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "gray-slate":   return LinearGradient(colors: [.gray, Color(red: 0.42, green: 0.48, blue: 0.55)], startPoint: .topLeading, endPoint: .bottomTrailing)
        default:             return LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(gradientColors)
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                }
                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.50))
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Dashboard Widget Card

struct DashboardWidgetCard: View {
    let title: String
    let value: String
    var unit: String? = nil
    var icon: String? = nil

    var body: some View {
        HeroCard {
            HStack {
                VStack(alignment: .leading, spacing: 10) {
                    Text(title.uppercased())
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.35))
                        .tracking(1.2)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(value)
                            .font(AppTypography.largeValue)
                            .foregroundStyle(AppColors.ink)
                        if let unit {
                            Text(unit)
                                .font(AppTypography.caratDisplay)
                                .foregroundStyle(AppColors.inkMuted)
                        }
                    }
                }
                Spacer()
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundStyle(AppColors.primary.opacity(0.40))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
