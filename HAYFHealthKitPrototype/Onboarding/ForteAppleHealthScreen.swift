import SwiftUI

enum ForteHealthConnectionState: Equatable {
    case idle
    case requesting
    case connected
    case sampleData
    case unavailable
    case failed

    var label: String {
        switch self {
        case .idle: return "Ready to connect"
        case .requesting: return "Connecting"
        case .connected: return "Connected"
        case .sampleData: return "Sample data ready"
        case .unavailable: return "Unavailable"
        case .failed: return "Needs attention"
        }
    }

    var systemImage: String {
        switch self {
        case .idle: return "arrow.triangle.2.circlepath"
        case .requesting: return "ellipsis"
        case .connected, .sampleData: return "checkmark"
        case .unavailable: return "minus"
        case .failed: return "exclamationmark"
        }
    }
}

struct ForteAppleHealthScreen: View {
    @Binding var usesSampleData: Bool

    let connectionState: ForteHealthConnectionState
    let stateMessage: String?
    let completionErrorMessage: String?
    let progressStep: Int
    let totalSteps: Int
    let primaryButtonTitle: String
    let onSampleDataChanged: (Bool) -> Void
    let onBack: () -> Void
    let onExit: () -> Void
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            ForteColor.background
                .ignoresSafeArea()

            balancedObjectsBackground

            VStack(spacing: 0) {
                progressHeader

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        hero
                        appleHealthIdentityCard

                        sectionLabel("WHAT FORTE USES")
                            .padding(.top, 26)
                            .padding(.bottom, 12)

                        ForteHealthDataList()

                        privacyCard
                            .padding(.top, 18)

                        sampleDataToggle
                            .padding(.top, 16)

                        if let message = stateMessage {
                            ForteHealthMessageCard(
                                message: message,
                                isError: connectionState == .failed
                            )
                            .padding(.top, 14)
                        }

                        if let completionErrorMessage {
                            ForteHealthMessageCard(
                                message: completionErrorMessage,
                                isError: true
                            )
                            .padding(.top, 14)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }

                continueAction
            }
            .frame(maxWidth: 480)
        }
    }

    private var balancedObjectsBackground: some View {
        GeometryReader { geometry in
            let artworkWidth = min(164, geometry.size.width * 0.39)

            Image("ForteBalancedObjectsIllustration")
                .resizable()
                .scaledToFit()
                .frame(width: artworkWidth)
                .position(
                    x: geometry.size.width * 0.90,
                    y: min(286, geometry.size.height * 0.30)
                )
                .opacity(0.40)
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
                Text("Step \(progressStep) of \(totalSteps)")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(ForteColor.inkMuted)

                Spacer()

                HStack(spacing: 8) {
                    ForteHealthHeaderButton(systemName: "arrow.left", action: onBack)
                        .accessibilityLabel("Back")

                    ForteHealthHeaderButton(systemName: "xmark", action: onExit)
                        .accessibilityLabel("Exit onboarding")
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("ONBOARDING")
                .font(.system(size: 11, weight: .semibold))
                .tracking(3.4)
                .foregroundStyle(ForteColor.indigoDeep)

            Text("Connect\nApple Health.")
                .font(ForteTypography.editorial(size: 32, relativeTo: .largeTitle))
                .tracking(-0.4)
                .foregroundStyle(ForteColor.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)

            Text("Bring your activity and recovery into Forte\nbefore it builds your first plan.")
                .font(.system(size: 15, weight: .regular))
                .lineSpacing(5)
                .foregroundStyle(ForteColor.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .padding(.bottom, 24)
        }
    }

    private var appleHealthIdentityCard: some View {
        HStack(spacing: 16) {
            Image("AppleHealthDeveloperIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 76, height: 76)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                Text("Apple Health")
                    .font(ForteTypography.editorial(size: 20, relativeTo: .headline))
                    .foregroundStyle(ForteColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.88)

                Text("Read-only health connection")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(ForteColor.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.88)
                    .padding(.top, 4)

                statusCapsule
                    .padding(.top, 11)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(ForteColor.surface.opacity(0.98))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(ForteColor.borderSubtle.opacity(0.82), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.07), radius: 18, y: 10)
        .accessibilityElement(children: .combine)
    }

    private var statusCapsule: some View {
        HStack(spacing: 5) {
            Image(systemName: connectionState.systemImage)
                .font(.system(size: 10, weight: .bold))

            Text(connectionState.label)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
        }
        .fixedSize(horizontal: true, vertical: false)
        .foregroundStyle(statusForeground)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(statusBackground)
        .clipShape(Capsule())
    }

    private var privacyCard: some View {
        HStack(alignment: .top, spacing: 13) {
            ForteReviewIconBadge(
                systemName: "lock.fill",
                palette: .blue
            )

            VStack(alignment: .leading, spacing: 5) {
                Text("Private by design")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ForteColor.ink)

                Text("Forte computes features locally first. Its coach receives compact summaries, not raw HealthKit samples.")
                    .font(.system(size: 13, weight: .regular))
                    .lineSpacing(3)
                    .foregroundStyle(ForteColor.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(ForteColor.indigoMist.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var sampleDataToggle: some View {
        Toggle(isOn: $usesSampleData) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Use simulator sample data")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ForteColor.ink)

                Text("Loads the local fixture instead of requesting Apple Health.")
                    .font(.system(size: 13, weight: .regular))
                    .lineSpacing(3)
                    .foregroundStyle(ForteColor.inkMuted)
            }
        }
        .tint(ForteColor.indigo)
        .padding(16)
        .background(ForteColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(ForteColor.borderSubtle, lineWidth: 1)
        }
        .onChange(of: usesSampleData) { _, isEnabled in
            onSampleDataChanged(isEnabled)
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .tracking(2.6)
            .foregroundStyle(ForteColor.inkMuted)
    }

    private var continueAction: some View {
        Button(action: onContinue) {
            HStack(spacing: 12) {
                if connectionState == .requesting {
                    ProgressView()
                        .tint(Color.white)
                        .accessibilityHidden(true)
                }

                Text(primaryButtonTitle)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)

                Image(systemName: "arrow.right")
                    .font(.system(size: 20, weight: .regular))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 20)
            .frame(height: 56)
            .background(ForteColor.indigo)
            .clipShape(Capsule())
            .shadow(color: ForteColor.indigoDeep.opacity(0.18), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
        .disabled(connectionState == .requesting)
        .opacity(connectionState == .requesting ? 0.72 : 1)
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .padding(.bottom, 18)
        .background(ForteColor.background.opacity(0.97).ignoresSafeArea(edges: .bottom))
    }

    private var statusForeground: Color {
        switch connectionState {
        case .connected, .sampleData: return ForteColor.indigoDeep
        case .failed: return Color(red: 0.68, green: 0.23, blue: 0.30)
        default: return ForteColor.inkMuted
        }
    }

    private var statusBackground: Color {
        switch connectionState {
        case .connected, .sampleData: return ForteColor.indigoSoft
        case .failed: return Color(red: 0.99, green: 0.91, blue: 0.92)
        default: return ForteColor.surfaceSoft
        }
    }
}

private struct ForteHealthDataList: View {
    private let rows = [
        ForteHealthDataItem(
            systemImage: "figure.strengthtraining.traditional",
            title: "Training history",
            copy: "Workouts, modalities, duration and recency."
        ),
        ForteHealthDataItem(
            systemImage: "figure.walk",
            title: "Daily activity",
            copy: "Steps, active energy and exercise minutes."
        ),
        ForteHealthDataItem(
            systemImage: "moon.stars",
            title: "Recovery",
            copy: "Sleep, resting heart rate, HRV and cardio fitness."
        ),
        ForteHealthDataItem(
            systemImage: "figure",
            title: "Body context",
            copy: "Body metrics and available nutrition logs."
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                HStack(alignment: .top, spacing: 12) {
                    ForteReviewIconBadge(
                        systemName: row.systemImage,
                        palette: .cycling(index)
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(ForteColor.ink)

                        Text(row.copy)
                            .font(.system(size: 13, weight: .regular))
                            .lineSpacing(3)
                            .foregroundStyle(ForteColor.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .accessibilityElement(children: .combine)

                if index < rows.count - 1 {
                    Rectangle()
                        .fill(ForteColor.borderSubtle.opacity(0.78))
                        .frame(height: 1)
                        .padding(.leading, 66)
                }
            }
        }
        .padding(.vertical, 4)
        .background(ForteColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(ForteColor.borderSubtle.opacity(0.86), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.055), radius: 16, y: 9)
    }
}

private struct ForteHealthDataItem: Identifiable {
    let systemImage: String
    let title: String
    let copy: String

    var id: String { title }
}

private struct ForteHealthMessageCard: View {
    let message: String
    let isError: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isError ? Color(red: 0.68, green: 0.23, blue: 0.30) : ForteColor.indigo)

            Text(message)
                .font(.system(size: 13, weight: .regular))
                .lineSpacing(3)
                .foregroundStyle(ForteColor.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(isError ? Color(red: 0.99, green: 0.94, blue: 0.94) : ForteColor.indigoMist)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct ForteHealthHeaderButton: View {
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
