import SwiftUI

struct HAYFLogo: View {
    var markSize: CGFloat = 48
    var textSize: CGFloat = 42
    var spacing: CGFloat = 13

    var body: some View {
        HStack(alignment: .center, spacing: spacing) {
            Image("HAYFMark")
                .resizable()
                .scaledToFit()
                .frame(width: markSize, height: markSize)

            Text("HAYF")
                .font(.system(size: textSize, weight: .black, design: .default))
                .foregroundStyle(.black)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("HAYF")
    }
}
