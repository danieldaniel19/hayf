import SwiftUI

struct ForteWheelSelector<Option: Identifiable & Hashable>: View where Option.ID: Hashable {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String
    let accessibilityLabel: String

    @State private var positionedID: Option.ID?

    private let rowHeight: CGFloat = 48
    private let wheelHeight: CGFloat = 176

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(ForteColor.indigoMist)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(ForteColor.indigo.opacity(0.14), lineWidth: 1)
                }
                .frame(height: rowHeight)

            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(options) { option in
                        Button {
                            select(option)
                        } label: {
                            Text(title(option))
                                .font(.system(size: 19, weight: isPositioned(option) ? .semibold : .medium, design: .rounded))
                                .foregroundStyle(isPositioned(option) ? ForteColor.indigoDeep : ForteColor.inkMuted)
                                .lineLimit(1)
                                .minimumScaleFactor(0.74)
                                .frame(maxWidth: .infinity)
                                .frame(height: rowHeight)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .id(option.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .contentMargins(.vertical, (wheelHeight - rowHeight) / 2, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            .scrollPosition(id: $positionedID, anchor: .center)
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .white.opacity(0.45), location: 0.16),
                        .init(color: .white, location: 0.34),
                        .init(color: .white, location: 0.66),
                        .init(color: .white.opacity(0.45), location: 0.84),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .frame(height: wheelHeight)
        .onAppear {
            positionedID = selection.id
        }
        .onChange(of: positionedID) { _, newID in
            guard
                let newID,
                let option = options.first(where: { $0.id == newID }),
                option != selection
            else { return }
            selection = option
        }
        .onChange(of: selection) { _, newSelection in
            guard positionedID != newSelection.id else { return }
            withAnimation(.snappy(duration: 0.22)) {
                positionedID = newSelection.id
            }
        }
        .sensoryFeedback(.selection, trigger: positionedID)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(title(selection))
        .accessibilityAdjustableAction(adjustSelection)
    }

    private func isPositioned(_ option: Option) -> Bool {
        option.id == (positionedID ?? selection.id)
    }

    private func select(_ option: Option) {
        selection = option
        withAnimation(.snappy(duration: 0.22)) {
            positionedID = option.id
        }
    }

    private func adjustSelection(_ direction: AccessibilityAdjustmentDirection) {
        guard let currentIndex = options.firstIndex(of: selection) else { return }

        let nextIndex: Int
        switch direction {
        case .increment:
            nextIndex = min(options.index(before: options.endIndex), currentIndex + 1)
        case .decrement:
            nextIndex = max(options.startIndex, currentIndex - 1)
        @unknown default:
            return
        }

        select(options[nextIndex])
    }
}
