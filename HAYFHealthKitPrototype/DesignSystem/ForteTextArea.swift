import SwiftUI

struct ForteTextArea: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let characterLimit: Int

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ForteColor.ink)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(.system(size: 15, weight: .regular))
                    .lineSpacing(4)
                    .foregroundStyle(ForteColor.ink)
                    .scrollContentBackground(.hidden)
                    .focused($isFocused)
                    .padding(.horizontal, 11)
                    .padding(.top, 9)
                    .padding(.bottom, 34)

                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 15, weight: .regular))
                        .lineSpacing(4)
                        .foregroundStyle(ForteColor.inkMuted.opacity(0.62))
                        .padding(.horizontal, 16)
                        .padding(.top, 17)
                        .allowsHitTesting(false)
                }

                Text("\(text.count)/\(characterLimit)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isFocused ? ForteColor.indigoDeep : ForteColor.inkMuted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(14)
                    .allowsHitTesting(false)
            }
            .frame(minHeight: 148)
            .background(ForteColor.surface.opacity(0.97))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        isFocused ? ForteColor.indigo.opacity(0.76) : ForteColor.borderSubtle.opacity(0.82),
                        lineWidth: isFocused ? 1.4 : 1
                    )
            }
            .shadow(color: Color.black.opacity(isFocused ? 0.065 : 0.035), radius: 10, y: 4)
            .animation(.easeOut(duration: 0.16), value: isFocused)
        }
        .onChange(of: text) { _, newValue in
            guard newValue.count > characterLimit else { return }
            text = String(newValue.prefix(characterLimit))
        }
    }
}
