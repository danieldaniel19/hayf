import SwiftUI

struct ForteBlueprintSnapshotItem: Identifiable, Equatable {
    let label: String
    let systemImage: String
    let title: String
    let summary: String

    var id: String { label }
}

struct ForteBlueprintHistoryItem: Identifiable, Equatable {
    let id: String
    let title: String
    let summary: String
}

struct ForteBlueprintGoalFit: Equatable {
    let headline: String
    let summary: String
    let supports: [String]
    let gaps: [String]
}

struct ForteAthleteBlueprintScreen: View {
    let coachRead: String
    let snapshotItems: [ForteBlueprintSnapshotItem]
    let historyItems: [ForteBlueprintHistoryItem]
    let goalFit: ForteBlueprintGoalFit
    let progressStep: Int
    let totalSteps: Int
    let onAccept: () -> Void
    let onEdit: () -> Void
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

                        ForteAIReadbackCard(
                            label: "COACH'S READ",
                            text: coachRead,
                            footer: "Built from your answers and available health data"
                        )

                        sectionLabel("BLUEPRINT SNAPSHOT")
                            .padding(.top, 28)
                            .padding(.bottom, 12)

                        ForteBlueprintSnapshotList(items: snapshotItems)

                        if !historyItems.isEmpty {
                            sectionLabel("WHAT YOUR HISTORY SHOWS")
                                .padding(.top, 28)
                                .padding(.bottom, 12)

                            ForteBlueprintHistoryList(items: historyItems)
                        }

                        sectionLabel("GOAL FIT")
                            .padding(.top, 28)
                            .padding(.bottom, 12)

                        ForteBlueprintGoalFitCard(goalFit: goalFit)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }

                bottomActions
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
            Text("ATHLETE BLUEPRINT")
                .font(.system(size: 11, weight: .semibold))
                .tracking(3.2)
                .foregroundStyle(ForteColor.indigoDeep)

            Text("Here's how\nForte sees you.")
                .font(ForteTypography.editorial(size: 32, relativeTo: .largeTitle))
                .tracking(-0.4)
                .foregroundStyle(ForteColor.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)

            Text("A coach's view of your history,\ncurrent baseline and goal fit.")
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

    private var bottomActions: some View {
        VStack(spacing: 10) {
            Button(action: onAccept) {
                HStack(spacing: 12) {
                    Text("Accept blueprint")
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
            .accessibilityHint("Accepts this athlete blueprint and continues onboarding.")

            Button(action: onEdit) {
                Text("Edit answers")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ForteColor.indigoDeep)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(ForteColor.surface)
                    .clipShape(Capsule())
                    .overlay {
                        Capsule()
                            .stroke(ForteColor.borderSubtle, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityHint("Returns to the first editable onboarding answer.")
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .padding(.bottom, 18)
        .background(ForteColor.background.opacity(0.97).ignoresSafeArea(edges: .bottom))
    }
}

private struct ForteBlueprintSnapshotList: View {
    let items: [ForteBlueprintSnapshotItem]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                ForteBlueprintSnapshotRow(item: item)

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

private struct ForteBlueprintSnapshotRow: View {
    let item: ForteBlueprintSnapshotItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.systemImage)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(ForteColor.indigoDeep)
                .frame(width: 38, height: 38)
                .background(ForteColor.indigoMist)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.label.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(ForteColor.inkMuted)

                Text(item.title)
                    .font(ForteTypography.editorial(size: 17, relativeTo: .headline))
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
    }
}

private struct ForteBlueprintHistoryList: View {
    let items: [ForteBlueprintHistoryItem]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
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

private struct ForteBlueprintGoalFitCard: View {
    let goalFit: ForteBlueprintGoalFit

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "scope")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(ForteColor.indigoDeep)
                    .frame(width: 38, height: 38)
                    .background(ForteColor.indigoSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    Text(goalFit.headline)
                        .font(ForteTypography.editorial(size: 18, relativeTo: .headline))
                        .foregroundStyle(ForteColor.ink)

                    Text(goalFit.summary)
                        .font(.system(size: 13, weight: .regular))
                        .lineSpacing(3)
                        .foregroundStyle(ForteColor.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !goalFit.supports.isEmpty {
                ForteBlueprintSignalGroup(
                    title: "What supports it",
                    systemImage: "checkmark",
                    items: goalFit.supports
                )
            }

            if !goalFit.gaps.isEmpty {
                ForteBlueprintSignalGroup(
                    title: "What to account for",
                    systemImage: "minus",
                    items: goalFit.gaps
                )
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

private struct ForteBlueprintSignalGroup: View {
    let title: String
    let systemImage: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(ForteColor.inkMuted)

            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: systemImage)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(ForteColor.indigoDeep)
                        .frame(width: 18, height: 18)
                        .background(ForteColor.indigoSoft)
                        .clipShape(Circle())

                    Text(item)
                        .font(.system(size: 13, weight: .regular))
                        .lineSpacing(3)
                        .foregroundStyle(ForteColor.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
