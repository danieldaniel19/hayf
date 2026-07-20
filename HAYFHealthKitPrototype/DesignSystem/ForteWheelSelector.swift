import SwiftUI

struct ForteWheelSelector<Option: Identifiable & Hashable>: View where Option.ID: Hashable {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String
    let accessibilityLabel: String

    private let wheelHeight: CGFloat = 152

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(options) { option in
                Text(title(option))
                    .font(.system(size: 18, weight: option == selection ? .semibold : .medium, design: .rounded))
                    .foregroundStyle(option == selection ? ForteColor.indigoDeep : ForteColor.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
                    .tag(option)
            }
        }
        .labelsHidden()
        .pickerStyle(.wheel)
        .colorScheme(.light)
        .tint(ForteColor.indigoDeep)
        .frame(maxWidth: .infinity)
        .frame(height: wheelHeight)
        .clipped()
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(title(selection))
    }
}
