import SwiftUI

/// Shimmer loading placeholder for list views.
struct ShimmerView: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        VStack(spacing: AppSpacing.s) {
            ForEach(0..<5, id: \.self) { _ in
                shimmerRow
            }
        }
        .padding(AppSpacing.m)
        .onAppear {
            withAnimation(AppAnimation.shimmer) {
                phase = 1
            }
        }
    }

    private var shimmerRow: some View {
        HStack(spacing: AppSpacing.m) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .frame(width: 80, height: 14)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .frame(width: 120, height: 14)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .frame(width: 60, height: 14)
            Spacer()
        }
        .padding(.vertical, AppSpacing.s)
        .overlay(
            GeometryReader { geo in
                LinearGradient(
                    colors: [.clear, Color.white.opacity(0.06), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: geo.size.width * 0.4)
                .offset(x: -geo.size.width * 0.4 + geo.size.width * 1.4 * phase)
            }
            .clipped()
        )
    }
}
