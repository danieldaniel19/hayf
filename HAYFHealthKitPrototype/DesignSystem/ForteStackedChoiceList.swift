import SwiftUI

struct ForteStackedChoiceItem: Identifiable, Equatable {
    let id: String
    let title: String
    let assetName: String
}

struct ForteStackedChoiceList: View {
    let items: [ForteStackedChoiceItem]
    let selectedIDs: Set<String>
    let onToggle: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                ForteStackedChoiceRow(
                    item: item,
                    isSelected: selectedIDs.contains(item.id)
                ) {
                    onToggle(item.id)
                }

                if index < items.count - 1 {
                    Divider()
                        .overlay(ForteColor.borderSubtle.opacity(0.72))
                        .padding(.leading, 80)
                        .padding(.trailing, 18)
                }
            }
        }
        .background(ForteColor.surface.opacity(0.97))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(ForteColor.borderSubtle.opacity(0.58), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.045), radius: 12, y: 5)
    }
}

private struct ForteStackedChoiceRow: View {
    let item: ForteStackedChoiceItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(item.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .accessibilityHidden(true)

                Text(item.title)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(ForteColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .layoutPriority(1)

                Spacer(minLength: 12)

                ForteStackedChoiceIndicator(isSelected: isSelected)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 68)
            .background(isSelected ? ForteColor.indigoMist : ForteColor.surface.opacity(0.001))
            .contentShape(Rectangle())
        }
        .buttonStyle(ForteStackedChoiceButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint(isSelected ? "Double tap to remove this option." : "Double tap to select this option.")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct ForteStackedChoiceIndicator: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? ForteColor.indigo : Color.clear)

            Circle()
                .stroke(
                    isSelected ? ForteColor.indigo : ForteColor.inkMuted.opacity(0.48),
                    lineWidth: isSelected ? 0 : 1.5
                )

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.white)
            }
        }
        .frame(width: 26, height: 26)
    }
}

private struct ForteStackedChoiceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.9 : 1)
            .scaleEffect(configuration.isPressed ? 0.995 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
