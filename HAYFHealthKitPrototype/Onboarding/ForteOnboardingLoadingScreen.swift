import SwiftUI

struct ForteOnboardingLoadingContent: Equatable {
    let title: String
    let copy: String
    let activityTitle: String
    let activityCopy: String
}

struct ForteOnboardingLoadingFailure: Equatable {
    let title: String
    let copy: String
    let detail: String
}

struct ForteOnboardingLoadingScreen: View {
    let content: ForteOnboardingLoadingContent
    let failure: ForteOnboardingLoadingFailure?
    let progressStep: Int
    let totalSteps: Int
    let onRetry: () -> Void
    let onBack: () -> Void
    let onExit: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false

    private var hasFailure: Bool {
        failure != nil
    }

    var body: some View {
        ZStack {
            ForteColor.background
                .ignoresSafeArea()

            ambientBackground

            VStack(spacing: 0) {
                progressHeader

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        hero

                        if hasFailure {
                            ForteGenerationFailureCard(
                                detail: failure?.detail ?? "Check your connection and try again.",
                                onRetry: onRetry
                            )
                        } else {
                            ForteBuildingMark(isAnimating: isAnimating)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 28)

                            ForteGenerationStatusCard(
                                title: content.activityTitle,
                                copy: content.activityCopy,
                                isAnimating: isAnimating
                            )
                            .padding(.top, 24)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .frame(maxWidth: 480)
        }
        .onAppear {
            guard !reduceMotion else { return }
            isAnimating = true
        }
        .onChange(of: reduceMotion) { _, shouldReduceMotion in
            isAnimating = !shouldReduceMotion
        }
    }

    private var ambientBackground: some View {
        GeometryReader { geometry in
            Circle()
                .fill(ForteColor.indigoMist.opacity(0.72))
                .frame(width: 260, height: 260)
                .blur(radius: 2)
                .position(x: geometry.size.width * 0.94, y: geometry.size.height * 0.42)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Capsule()
                        .fill(index < progressStep ? ForteColor.indigoDeep : ForteColor.borderSubtle)
                        .frame(height: 3)
                }
            }

            HStack(spacing: 12) {
                Text(hasFailure ? "Paused" : "Building")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(ForteColor.inkMuted)

                Spacer()

                HStack(spacing: 8) {
                    ForteLoadingHeaderButton(systemName: "arrow.left", action: onBack)
                        .accessibilityLabel("Back")

                    ForteLoadingHeaderButton(systemName: "xmark", action: onExit)
                        .accessibilityLabel("Exit onboarding")
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(hasFailure ? "LET'S TRY THAT AGAIN" : "FORTE IS BUILDING")
                .font(.system(size: 11, weight: .semibold))
                .tracking(3.1)
                .foregroundStyle(hasFailure ? ForteColor.inkMuted : ForteColor.indigoDeep)

            Text(failure?.title ?? content.title)
                .font(ForteTypography.editorial(size: 34, relativeTo: .largeTitle))
                .tracking(-0.4)
                .foregroundStyle(ForteColor.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)

            Text(failure?.copy ?? content.copy)
                .font(.system(size: 15, weight: .regular))
                .lineSpacing(5)
                .foregroundStyle(ForteColor.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
        }
    }
}

private struct ForteBuildingMark: View {
    let isAnimating: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(ForteColor.surface.opacity(0.96))
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(ForteColor.borderSubtle.opacity(0.74), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.08), radius: 24, y: 14)

            Circle()
                .fill(ForteColor.indigoMist)
                .frame(width: 142, height: 142)
                .scaleEffect(isAnimating ? 1.05 : 0.94)

            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.94, green: 0.91, blue: 0.84), Color.white],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 124, height: 20)
                .rotationEffect(.degrees(-8))
                .offset(y: 49)
                .shadow(color: Color.black.opacity(0.09), radius: 8, y: 6)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white, Color(red: 0.88, green: 0.87, blue: 0.83)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 78, height: 78)
                .offset(x: -13, y: 5)
                .shadow(color: Color.black.opacity(0.11), radius: 10, y: 7)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [ForteColor.indigo, ForteColor.indigoDeep],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 78, height: 13)
                .rotationEffect(.degrees(isAnimating ? -20 : -27))
                .offset(x: -28, y: 15)
                .shadow(color: ForteColor.indigoDeep.opacity(0.22), radius: 6, y: 4)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.78, green: 0.83, blue: 0.80), Color(red: 0.54, green: 0.61, blue: 0.59)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 46, height: 46)
                .offset(x: 48, y: isAnimating ? 36 : 43)
                .shadow(color: Color.black.opacity(0.13), radius: 8, y: 6)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.82, green: 0.76, blue: 1.0), ForteColor.indigo],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 22, height: 22)
                .offset(x: -55, y: isAnimating ? -52 : -42)
                .shadow(color: ForteColor.indigo.opacity(0.18), radius: 6, y: 4)
        }
        .frame(width: 214, height: 214)
        .animation(
            .easeInOut(duration: 1.6).repeatForever(autoreverses: true),
            value: isAnimating
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Forte is building your onboarding result")
    }
}

private struct ForteGenerationStatusCard: View {
    let title: String
    let copy: String
    let isAnimating: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 13) {
                ZStack {
                    Circle()
                        .fill(ForteColor.indigoMist)
                        .frame(width: 38, height: 38)

                    Circle()
                        .stroke(ForteColor.indigo.opacity(0.26), lineWidth: 2)
                        .frame(width: 20, height: 20)

                    Circle()
                        .fill(ForteColor.indigo)
                        .frame(width: 7, height: 7)
                        .scaleEffect(isAnimating ? 1.28 : 0.82)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(ForteColor.ink)

                    Text(copy)
                        .font(.system(size: 14, weight: .regular))
                        .lineSpacing(3)
                        .foregroundStyle(ForteColor.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(ForteColor.surfaceRaised)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [ForteColor.indigoSoft, ForteColor.indigo, ForteColor.indigoSoft],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * 0.42)
                        .offset(x: isAnimating ? geometry.size.width * 0.58 : 0)
                }
            }
            .frame(height: 5)
        }
        .padding(18)
        .background(ForteColor.surface.opacity(0.98))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(ForteColor.borderSubtle.opacity(0.82), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.06), radius: 16, y: 9)
        .animation(
            .easeInOut(duration: 1.35).repeatForever(autoreverses: true),
            value: isAnimating
        )
        .accessibilityElement(children: .combine)
    }
}

private struct ForteGenerationFailureCard: View {
    let detail: String
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 13) {
                Image(systemName: "exclamationmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(ForteColor.indigoDeep)
                    .frame(width: 38, height: 38)
                    .background(ForteColor.indigoMist)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text("We couldn't finish this step")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(ForteColor.ink)

                    Text(detail)
                        .font(.system(size: 14, weight: .regular))
                        .lineSpacing(3)
                        .foregroundStyle(ForteColor.inkSoft)
                }
            }

            Button(action: onRetry) {
                HStack(spacing: 10) {
                    Text("Try again")
                        .font(.system(size: 15, weight: .semibold))

                    Spacer()

                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, 18)
                .frame(height: 48)
                .background(ForteColor.indigo)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(ForteColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(ForteColor.borderSubtle, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.06), radius: 16, y: 9)
        .padding(.top, 28)
    }
}

private struct ForteLoadingHeaderButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(ForteColor.indigoDeep)
                .frame(width: 44, height: 44)
                .background(ForteColor.surface.opacity(0.96))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(ForteColor.borderSubtle.opacity(0.72), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.07), radius: 9, y: 4)
        }
        .buttonStyle(.plain)
    }
}
