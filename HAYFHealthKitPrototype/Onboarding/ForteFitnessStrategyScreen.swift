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

struct ForteFitnessStrategyScreen: View {
    let coachVerdict: String
    let snapshotItems: [ForteStrategySnapshotItem]
    let fitReasons: [ForteStrategyEvidenceItem]
    let priorities: [ForteStrategyEvidenceItem]
    let targets: [ForteStrategyTargetItem]
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
                    Image(snapshotAssetName(for: item))
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 48, height: 48)
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

    private func snapshotAssetName(for item: ForteStrategySnapshotItem) -> String {
        let label = item.label.lowercased()

        if label.contains("primary") || label.contains("driver") {
            return "ForteStrategyDriver"
        }
        if label.contains("budget") || label.contains("session") || label.contains("frequency") {
            return "ForteSummaryCapacity"
        }
        if label.contains("horizon") || label.contains("timeframe") || label == "weeks" {
            return "ForteSummaryAvailability"
        }
        if label.contains("tradeoff") {
            return "ForteStrategyTradeoff"
        }
        if label.contains("priorit") {
            return "ForteSummaryTraining"
        }

        switch item.id {
        case "timeframe": return "ForteSummaryAvailability"
        case "frequency": return "ForteSummaryCapacity"
        case "priorities": return "ForteSummaryTraining"
        default: return "ForteStrategyTarget"
        }
    }
}

private struct ForteStrategyEvidenceList: View {
    let items: [ForteStrategyEvidenceItem]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HStack(alignment: .top, spacing: 12) {
                    evidenceIcon(for: item, index: index)

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
                        .padding(.leading, 76)
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

    @ViewBuilder
    private func evidenceIcon(for item: ForteStrategyEvidenceItem, index: Int) -> some View {
        if let assetName = evidenceAssetName(for: item) {
            Image(assetName)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 48, height: 48)
                .accessibilityHidden(true)
        } else {
            ForteReviewIconBadge(
                systemName: item.systemImage,
                palette: .cycling(index),
                size: 48,
                iconSize: 18
            )
        }
    }

    private func evidenceAssetName(for item: ForteStrategyEvidenceItem) -> String? {
        let title = item.title.lowercased()

        if title.contains("built for you") || title.contains("athlete") || title.contains("blueprint") {
            return "ForteBlueprintAthleteType"
        }
        if title.contains("core work") || title.contains("training first") {
            return "ForteSummaryTraining"
        }
        if title.contains("recovery") || title.contains("drop-off") || title.contains("drop off") {
            return "ForteHealthRecovery"
        }
        if title.contains("protect") {
            return "ForteStrategyProtect"
        }
        if title.contains("support") {
            return "ForteSummarySupport"
        }
        if title.contains("progress") || title.contains("earn") {
            return "ForteStrategyPriority"
        }
        if title.contains("friction") || title.contains("access") || title.contains("setup") {
            return "ForteSummaryAccess"
        }
        if title.contains("floor") {
            return "ForteSummaryFloor"
        }
        if title.contains("window") || title.contains("available") {
            return "ForteSummaryAvailability"
        }

        switch item.id {
        case "available_window": return "ForteSummaryAvailability"
        case "training_access": return "ForteSummaryAccess"
        case "blueprint_base": return "ForteBlueprintAthleteType"
        default: return item.systemImage == "arrow.up.right" ? "ForteStrategyPriority" : nil
        }
    }
}

private struct ForteStrategyTargetList: View {
    let items: [ForteStrategyTargetItem]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HStack(alignment: .top, spacing: 12) {
                    Image(targetAssetName(for: item))
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 48, height: 48)
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
                        .padding(.leading, 76)
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

    private func targetAssetName(for item: ForteStrategyTargetItem) -> String {
        let id = item.id.lowercased()
        let title = item.title.lowercased()

        if id.contains("body_mass") || title.contains("body-mass") || title.contains("body trend") {
            return "ForteSummaryBodyBaseline"
        }
        if title.contains("strength") {
            return "ForteModalityStrength"
        }
        if id.contains("gap_recovery") || title.contains("drop-off") || title.contains("drop off") || title.contains("hard day") || title.contains("recovery cap") {
            return "ForteHealthRecovery"
        }
        if id.contains("anchor") || title.contains("stays visible") || title.contains("path protected") {
            return "ForteSummaryAnchor"
        }
        if id.contains("weekly_min_sessions") || id.contains("rhythm") || title.contains("sessions per week") {
            return "ForteSummaryCapacity"
        }
        if id.contains("goal_signal") || id.contains("strong_weeks") || title.contains("capstone") || title.contains("result captured") {
            return "ForteStrategyGoalSignal"
        }
        if id.contains("strength_exposure") || title.contains("strength exposure") {
            return "ForteSummaryTraining"
        }
        if id.contains("aerobic") || title.contains("aerobic") || title.contains("swimming min") || title.contains("running min") || title.contains("cycling min") {
            return "ForteStrategyGoalSignal"
        }

        return "ForteStrategyTarget"
    }
}
