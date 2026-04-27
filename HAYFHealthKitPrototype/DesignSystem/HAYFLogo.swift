import SwiftUI

struct HAYFLogo: View {
    var body: some View {
        HStack(alignment: .center, spacing: 13) {
            Image("HAYFMark")
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)

            Text("HAYF")
                .font(.system(size: 42, weight: .black, design: .default))
                .foregroundStyle(.black)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("HAYF")
    }
}
