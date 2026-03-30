import SwiftUI
import AppKit

extension StoneFormView {

    var editDiamondSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text("DIAMOND GRADING")
                .textCase(.uppercase)
                .sectionLabel(tracking: 1.2)
            if isDiamondLot {
                HStack(spacing: AppSpacing.m) {
                    editField("Color", binding: $color)
                    editField("Clarity", binding: $clarity)
                    editField("Size", binding: $sizeText)
                }
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: AppSpacing.s) {
                    editField("Color", binding: $color)
                    editField("Clarity", binding: $clarity)
                    editField("Cut", binding: $cut)
                    editField("Polish", binding: $polish)
                    editField("Symmetry", binding: $symmetry)
                    editField("Fluorescence", binding: $fluorescence)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.m)
        .glassCardBackground()
    }

    func editField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .captionLabel()
            content()
        }
    }

    func editField(_ label: String, binding: Binding<String>) -> some View {
        editField(label) {
            TextField("", text: binding)
                .glassField()
        }
    }

    var editCertificateMediaSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text("CERTIFICATE IMAGE & MEDIA")
                .textCase(.uppercase)
                .sectionLabel(tracking: 1.2)
            HStack(spacing: AppSpacing.s) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Certificate Image")
                        .captionLabel()
                    HStack(spacing: AppSpacing.s) {
                        Text(certificateImagePath.isEmpty ? "No file selected" : (certificateImagePath as NSString).lastPathComponent)
                            .font(.body)
                            .foregroundStyle(certificateImagePath.isEmpty ? Color.white.opacity(0.40) : AppColors.ink)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.white.opacity(0.04))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6, 3]))
                                            .foregroundStyle(Color.white.opacity(0.12))
                                    )
                            )
                        Button("Choose...") {
                            openCertificateImagePanel()
                        }
                        .buttonStyle(OutlineGlassButtonStyle())
                    }
                }
                Spacer()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Media")
                    .captionLabel()
                HStack(spacing: AppSpacing.s) {
                    Button("Add Media...") { showMediaPicker = true }
                        .buttonStyle(OutlineGlassButtonStyle())
                    if !mediaPathsLocal.isEmpty {
                        Text("\(mediaPathsLocal.count) file(s)")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.inkMuted)
                    }
                }
                if !mediaPathsLocal.isEmpty {
                    ForEach(Array(mediaPathsLocal.enumerated()), id: \.offset) { idx, path in
                        HStack {
                            Text((path as NSString).lastPathComponent)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.ink)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button { mediaPathsLocal.remove(at: idx) } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.danger.opacity(0.70))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.m)
        .glassCardBackground()
    }

    func openCertificateImagePanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.begin { response in
            if response == .OK, let url = panel.url {
                _ = url.startAccessingSecurityScopedResource()
                certificateImagePath = url.path
            }
        }
    }
}
