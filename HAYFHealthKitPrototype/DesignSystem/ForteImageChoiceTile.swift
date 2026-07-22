import SwiftUI

struct ForteImageChoiceTile: View {
    let title: String
    let assetName: String
    let isSelected: Bool
    var selectionBadge: String? = nil
    var isLocked = false
    var accessibilityValue: String? = nil
    var accessibilityHint: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 62, height: 62)
                    .opacity(isLocked ? 0.52 : 1)
                    .accessibilityHidden(true)

                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isLocked ? ForteColor.inkMuted : ForteColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(isSelected ? ForteColor.indigoMist : ForteColor.surface.opacity(0.96))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(ForteColor.inkMuted)
                        .padding(10)
                } else if let selectionBadge {
                    Text(selectionBadge)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(width: 22, height: 22)
                        .background(ForteColor.indigoDeep)
                        .clipShape(Circle())
                        .padding(8)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected ? ForteColor.indigo.opacity(0.62) : ForteColor.borderSubtle.opacity(0.78),
                        lineWidth: isSelected ? 1.3 : 1
                    )
            }
            .shadow(color: Color.black.opacity(isSelected ? 0.08 : 0.05), radius: 8, y: 4)
        }
        .buttonStyle(ForteImageChoiceTileButtonStyle())
        .disabled(isLocked)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isLocked ? "\(title), not available yet" : title)
        .accessibilityValue(accessibilityValue ?? (isSelected ? "Selected" : "Not selected"))
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct ForteImageChoiceTileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
