import SwiftUI

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(AppTypography.sectionLabel)
            .foregroundStyle(AppColors.inkSubtle)
            .tracking(1.5)
    }
}
