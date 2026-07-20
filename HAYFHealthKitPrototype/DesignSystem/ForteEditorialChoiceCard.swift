import SwiftUI

struct ForteEditorialChoiceCard: View {
    let title: String
    let subtitle: String
    let assetName: String
    var badge: String? = nil
    let isSelected: Bool
    var isEnabled = true
    var accessibilityHint = "Selects this option."
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: action) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    accessibilityLayout
                } else {
                    standardLayout
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
            .background(isSelected ? ForteColor.indigoMist : ForteColor.surface.opacity(0.96))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(ForteColor.borderSubtle.opacity(isSelected ? 0 : 0.62), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(isSelected ? 0.10 : 0.08), radius: 13, y: 7)
            .opacity(isEnabled ? 1 : 0.52)
        }
        .buttonStyle(ForteEditorialChoiceButtonStyle())
        .disabled(!isEnabled)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(accessibilityHint)
    }

    private var standardLayout: some View {
        HStack(spacing: 12) {
            choiceImage

            Rectangle()
                .fill(ForteColor.borderSubtle.opacity(0.72))
                .frame(width: 1, height: 68)
                .accessibilityHidden(true)

            copy

            Spacer(minLength: 8)

            ForteEditorialRadioControl(isSelected: isSelected)
        }
    }

    private var accessibilityLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                choiceImage
                Spacer()
                ForteEditorialRadioControl(isSelected: isSelected)
            }

            copy
        }
    }

    private var choiceImage: some View {
        Image(assetName)
            .resizable()
            .scaledToFit()
            .frame(width: 68, height: 68)
            .accessibilityHidden(true)
    }

    private var copy: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title)
                    .font(ForteTypography.editorial(size: 18, relativeTo: .headline))
                    .foregroundStyle(ForteColor.ink)

                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(ForteColor.indigoDeep)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(ForteColor.indigoMist)
                        .clipShape(Capsule())
                }
            }
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.78)
            .allowsTightening(true)
            .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(.system(size: 14, weight: .regular))
                .lineSpacing(3)
                .foregroundStyle(ForteColor.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var accessibilityLabel: String {
        [title, badge, subtitle]
            .compactMap { $0 }
            .joined(separator: ". ")
    }
}

private struct ForteEditorialRadioControl: View {
    let isSelected: Bool

    var body: some View {
        Circle()
            .fill(isSelected ? ForteColor.indigo : Color.clear)
            .frame(width: 24, height: 24)
            .overlay {
                Circle()
                    .stroke(isSelected ? ForteColor.indigo : ForteColor.indigoDeep, lineWidth: 1.8)
            }
            .overlay {
                if isSelected {
                    Circle()
                        .fill(.white)
                        .frame(width: 8, height: 8)
                }
            }
            .accessibilityHidden(true)
    }
}

private struct ForteEditorialChoiceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.992 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
