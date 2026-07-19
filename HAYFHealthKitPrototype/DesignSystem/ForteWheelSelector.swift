import SwiftUI

struct ForteWheelSelector<Option: Identifiable & Hashable>: View where Option.ID: Hashable {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String
    let accessibilityLabel: String

    private let rowHeight: CGFloat = 44
    private let wheelHeight: CGFloat = 152

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(ForteColor.indigoMist)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(ForteColor.indigo.opacity(0.14), lineWidth: 1)
                }
                .frame(height: rowHeight)
                .padding(.horizontal, 5)

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
        }
        .frame(height: wheelHeight)
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(title(selection))
    }
}
