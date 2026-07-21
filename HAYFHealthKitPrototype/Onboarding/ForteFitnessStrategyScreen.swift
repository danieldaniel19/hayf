import SwiftUI

struct ForteStrategySnapshotItem: Identifiable, Equatable {
    let id: String
    let systemImage: String
    let value: String
    let label: String
}

struct ForteStrategyEvidenceItem: Identifiable, Equatable {
    let id: String
    let systemImage: String
    let title: String
    let summary: String
}

struct ForteStrategyTargetItem: Identifiable, Equatable {
    let id: String
    let title: String
    let summary: String
    let displayValue: String?
}

struct ForteStrategyRhythm: Equatable {
    let summary: String
    let anchors: [String]
}

struct ForteFitnessStrategyScreen: View {
    let coachVerdict: String
    let snapshotItems: [ForteStrategySnapshotItem]
    let fitReasons: [ForteStrategyEvidenceItem]
    let priorities: [ForteStrategyEvidenceItem]
    let targets: [ForteStrategyTargetItem]
    let operatingRhythm: ForteStrategyRhythm?
    let completionErrorMessage: String?
    let progressStep: Int
    let totalSteps: Int
    let primaryButtonTitle: String
    let onContinue: () -> Void
    let onBack: () -> Void
    let onExit: () -> Void

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

                        sectionLabel("STRATEGY SNAPSHOT")
                            .padding(.bottom, 12)

                        ForteStrategySnapshotGrid(items: snapshotItems)

                        ForteAIReadbackCard(
                            label: "COACH VERDICT",
                            text: coachVerdict,
                            footer: "The direction Forte will coach from"
                        )
                        .padding(.top, 22)

                        if !fitReasons.isEmpty {
                            sectionLabel("WHY THIS FITS YOU")
                                .padding(.top, 28)
                                .padding(.bottom, 12)

                            ForteStrategyEvidenceList(items: fitReasons)
                        }

                        if !priorities.isEmpty {
                            sectionLabel("WHAT FORTE WILL PRIORITIZE")
                                .padding(.top, 28)
                                .padding(.bottom, 12)

                            ForteStrategyEvidenceList(items: priorities)
                        }

                        if !targets.isEmpty {
                            sectionLabel("STRATEGY TARGETS")
                                .padding(.top, 28)
                                .padding(.bottom, 12)

                            ForteStrategyTargetList(items: targets)
                        }

                        if let operatingRhythm {
                            sectionLabel("OPERATING RHYTHM")
                                .padding(.top, 28)
                                .padding(.bottom, 12)

                            ForteStrategyRhythmCard(rhythm: operatingRhythm)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }

                bottomAction
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
                    x: geometry.size.width * 0.89,
                    y: min(286, geometry.size.height * 0.30)
                )
                .opacity(0.44)
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
                    ForteSummaryHeaderButton(systemName: "arrow.left", action: onBack)
                        .accessibilityLabel("Back")

                    ForteSummaryHeaderButton(systemName: "xmark", action: onExit)
                        .accessibilityLabel("Exit onboarding")
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("FITNESS STRATEGY")
                .font(.system(size: 11, weight: .semibold))
                .tracking(3.2)
                .foregroundStyle(ForteColor.indigoDeep)

            Text("Your strategy\nis ready.")
                .font(ForteTypography.editorial(size: 32, relativeTo: .largeTitle))
                .tracking(-0.4)
                .foregroundStyle(ForteColor.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)

            Text("Your goal and Athlete Blueprint,\ntranslated into a coaching direction.")
                .font(.system(size: 15, weight: .regular))
                .lineSpacing(5)
                .foregroundStyle(ForteColor.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .padding(.bottom, 24)
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .tracking(2.4)
            .foregroundStyle(ForteColor.inkMuted)
    }

    private var bottomAction: some View {
        VStack(spacing: 10) {
            if let completionErrorMessage {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(red: 0.68, green: 0.23, blue: 0.30))

                    Text(completionErrorMessage)
                        .font(.system(size: 13, weight: .regular))
                        .lineSpacing(3)
                        .foregroundStyle(ForteColor.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
                .padding(13)
                .background(Color(red: 0.99, green: 0.94, blue: 0.94))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            Button(action: onContinue) {
                HStack(spacing: 12) {
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
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .padding(.bottom, 18)
        .background(ForteColor.background.opacity(0.97).ignoresSafeArea(edges: .bottom))
    }
}

private struct ForteStrategySnapshotGrid: View {
    let items: [ForteStrategySnapshotItem]
    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: item.systemImage)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(ForteColor.indigoDeep)
                        .frame(width: 38, height: 38)
                        .background(ForteColor.indigoSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.value)
                            .font(ForteTypography.editorial(size: 19, relativeTo: .headline))
                            .foregroundStyle(ForteColor.ink)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)

                        Text(item.label)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ForteColor.inkMuted)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .padding(15)
                .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
                .background(ForteColor.surface.opacity(0.98))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(ForteColor.borderSubtle.opacity(0.86), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.045), radius: 12, y: 7)
                .accessibilityElement(children: .combine)
            }
        }
    }
}

private struct ForteStrategyEvidenceList: View {
    let items: [ForteStrategyEvidenceItem]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: item.systemImage)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(ForteColor.indigoDeep)
                        .frame(width: 38, height: 38)
                        .background(ForteColor.indigoMist)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(ForteColor.ink)

                        Text(item.summary)
                            .font(.system(size: 13, weight: .regular))
                            .lineSpacing(3)
                            .foregroundStyle(ForteColor.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .accessibilityElement(children: .combine)

                if index < items.count - 1 {
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

private struct ForteStrategyTargetList: View {
    let items: [ForteStrategyTargetItem]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "scope")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(ForteColor.indigoDeep)
                        .frame(width: 38, height: 38)
                        .background(ForteColor.indigoMist)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(item.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(ForteColor.ink)
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer(minLength: 4)

                            if let displayValue = item.displayValue {
                                Text(displayValue)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(ForteColor.indigoDeep)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.82)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(ForteColor.indigoSoft)
                                    .clipShape(Capsule())
                            }
                        }

                        Text(item.summary)
                            .font(.system(size: 13, weight: .regular))
                            .lineSpacing(3)
                            .foregroundStyle(ForteColor.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .accessibilityElement(children: .combine)

                if index < items.count - 1 {
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

private struct ForteStrategyRhythmCard: View {
    let rhythm: ForteStrategyRhythm

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(ForteColor.indigoDeep)
                    .frame(width: 38, height: 38)
                    .background(ForteColor.indigoSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityHidden(true)

                Text(rhythm.summary)
                    .font(ForteTypography.editorial(size: 17, relativeTo: .headline))
                    .lineSpacing(4)
                    .foregroundStyle(ForteColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 9) {
                ForEach(Array(rhythm.anchors.enumerated()), id: \.offset) { _, anchor in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(ForteColor.indigoDeep)
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)

                        Text(anchor)
                            .font(.system(size: 13, weight: .regular))
                            .lineSpacing(3)
                            .foregroundStyle(ForteColor.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [ForteColor.indigoMist, ForteColor.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(ForteColor.indigoDeep.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: ForteColor.indigoDeep.opacity(0.08), radius: 18, y: 10)
        .accessibilityElement(children: .combine)
    }
}
