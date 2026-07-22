import SwiftUI

struct ProfileScreenView: View {
    let accountProfile: StoredAccountProfile
    let userEmail: String?
    let editProfile: () -> Void
    let reviewGoal: () -> Void
    let signOut: () -> Void

    @StateObject private var store = ProfileDataStore()
    @StateObject private var accountProfileStore = AccountProfileStore()
    @State private var didLoad = false
    @State private var selectedDetail: ProfileDetailSheet?
    @State private var profilePhotoURL: URL?

    var body: some View {
        ZStack {
            HAYFColor.neutral
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ProfileHeader()

                    Text("Profile")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(HAYFColor.primary)

                    ProfileIdentityCard(
                        profile: accountProfile,
                        profilePhotoURL: profilePhotoURL,
                        userEmail: userEmail,
                        editProfile: editProfile
                    )

                    CurrentStrategyCard(
                        block: store.activeBlock,
                        strategy: acceptedStrategy,
                        targets: strategyTargets,
                        phases: store.phases,
                        isLoading: store.isLoading && !didLoad,
                        openDetail: { selectedDetail = .currentStrategy }
                    )

                    AthleteBlueprintCard(
                        blueprint: store.athleteBlueprint,
                        isLoading: store.isLoading && !didLoad,
                        openDetail: { selectedDetail = .athleteBlueprint }
                    )

                    if let errorMessage = store.errorMessage {
                        ProfileInlineError(message: errorMessage)
                    }

                    Button(action: signOut) {
                        Text("Sign out")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(HAYFColor.primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 28)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .refreshable {
                await load()
            }
        }
        .task {
            guard !didLoad else { return }
            await load()
        }
        .sheet(item: $selectedDetail) { detail in
            ProfileDetailSheetView(
                detail: detail,
                block: store.activeBlock,
                strategy: acceptedStrategy,
                phases: store.phases,
                targets: store.goalTargets,
                evaluations: store.goalEvaluations,
                blueprint: store.athleteBlueprint,
                reviewGoal: reviewGoal
            )
            .presentationDetents(detail.detents)
            .presentationDragIndicator(.visible)
        }
    }

    private var acceptedStrategy: ProfileAcceptedStrategy? {
        guard let json = store.activeBlock?.context.acceptedStrategy, !json.profileIsEmpty else {
            return nil
        }
        return ProfileAcceptedStrategy(json: json)
    }

    private var strategyTargets: [PlanGoalTarget] {
        store.goalTargets.filter { $0.targetScope == .strategy }
    }

    private func load() async {
        async let profileContextLoad: Void = store.loadProfileContext()
        async let photoURLLoad = loadProfilePhotoURL()

        _ = await profileContextLoad
        profilePhotoURL = await photoURLLoad
        didLoad = true
    }

    private func loadProfilePhotoURL() async -> URL? {
        try? await accountProfileStore.displayPhotoURL(for: accountProfile)
    }
}

private enum ProfileDetailSheet: Identifiable {
    case currentStrategy
    case athleteBlueprint

    var id: String {
        switch self {
        case .currentStrategy:
            return "current-strategy"
        case .athleteBlueprint:
            return "athlete-blueprint"
        }
    }

    var detents: Set<PresentationDetent> {
        switch self {
        case .currentStrategy, .athleteBlueprint:
            return [.large]
        }
    }
}

private struct ProfileHeader: View {
    var body: some View {
        HStack(alignment: .center) {
            HAYFLogo(markSize: 34, textSize: 30, spacing: 10)

            Spacer()

            Button(action: {}) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 23, weight: .medium))
                        .foregroundStyle(HAYFColor.primary)
                        .frame(width: 54, height: 54)
                        .background(HAYFColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(HAYFColor.borderStrong, lineWidth: 1)
                        }

                    Circle()
                        .fill(HAYFColor.orange)
                        .frame(width: 10, height: 10)
                        .offset(x: 2, y: -2)
                }
            }
            .buttonStyle(.plain)
            .disabled(true)
            .accessibilityLabel("Coach chat coming soon")
        }
    }
}

private struct ProfileIdentityCard: View {
    let profile: StoredAccountProfile
    let profilePhotoURL: URL?
    let userEmail: String?
    let editProfile: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            ProfileAvatarView(name: profile.name, photoURL: profilePhotoURL)

            VStack(alignment: .leading, spacing: 5) {
                Text(profile.name)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(HAYFColor.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(ProfileDisplay.locationLine(profile: profile, userEmail: userEmail))
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(HAYFColor.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 10)

            Button(action: editProfile) {
                Image(systemName: "pencil")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(HAYFColor.primary)
                    .frame(width: 44, height: 44)
                    .background(HAYFColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(HAYFColor.borderStrong, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit profile")
        }
        .padding(18)
        .background(HAYFColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(HAYFColor.borderStrong, lineWidth: 1)
        }
    }
}

private struct ProfileAvatarView: View {
    let name: String
    let photoURL: URL?

    var body: some View {
        ZStack {
            Circle()
                .fill(HAYFColor.surfaceRaised)
                .frame(width: 62, height: 62)
                .overlay {
                    Circle()
                        .stroke(HAYFColor.borderStrong, lineWidth: 1)
                }

            if let photoURL {
                AsyncImage(url: photoURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        initials
                    }
                }
                .frame(width: 62, height: 62)
                .clipShape(Circle())
            } else {
                initials
            }
        }
    }

    private var initials: some View {
        Text(ProfileDisplay.initials(for: name))
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(HAYFColor.primary)
    }
}

private struct CurrentStrategyCard: View {
    let block: PlanActiveFitnessBlock?
    let strategy: ProfileAcceptedStrategy?
    let targets: [PlanGoalTarget]
    let phases: [PlanFitnessBlockPhase]
    let isLoading: Bool
    let openDetail: () -> Void

    var body: some View {
        ProfileEntryCard(action: openDetail, isDisabled: block == nil && !isLoading) {
            VStack(alignment: .leading, spacing: 15) {
                ProfileCardHeader(title: "Current strategy", subtitle: "How HAYF is coaching this goal.")

                if isLoading {
                    ProfileLoadingRow(text: "Loading current strategy")
                } else if let block {
                    VStack(alignment: .leading, spacing: 11) {
                        Text(block.title)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(HAYFColor.primary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Goal: \(ProfileDisplay.goalText(for: block))")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(HAYFColor.primary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(strategy?.read.profileNilIfEmpty ?? block.context.planningRationale ?? "HAYF will show the strategy details after planning finishes.")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(HAYFColor.secondary)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 8) {
                            ProfilePill(text: "\(targets.count) targets", tint: HAYFColor.secondary)
                            ProfilePill(text: phases.isEmpty ? "Rhythm" : "\(phases.count) phases", tint: HAYFColor.secondary)
                            ProfilePill(text: ProfileDisplay.reviewText(for: block), tint: HAYFColor.secondary)
                        }
                    }
                } else {
                    ProfileEmptyText(text: "No active strategy is available yet.")
                }
            }
        }
    }
}

private struct AthleteBlueprintCard: View {
    let blueprint: ProfileAthleteBlueprint?
    let isLoading: Bool
    let openDetail: () -> Void

    var body: some View {
        ProfileEntryCard(action: openDetail, isDisabled: blueprint == nil && !isLoading) {
            VStack(alignment: .leading, spacing: 16) {
                ProfileCardHeader(title: "Athlete Blueprint", subtitle: "Who HAYF believes it is coaching.")

                if isLoading {
                    ProfileLoadingRow(text: "Loading athlete blueprint")
                } else if let blueprint {
                    if let profileScores = blueprint.profileScores {
                        AthleteProfileChartCard(
                            scores: profileScores,
                            summary: blueprint.coachRead.summary,
                            layout: .profileCompact
                        )
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(blueprint.coachRead.summary)
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(HAYFColor.secondary)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)

                            ForEach(blueprint.previewSections.prefix(3)) { section in
                                ProfileIconSummaryRow(
                                    icon: ProfileDisplay.blueprintIcon(for: section),
                                    text: section.title,
                                    detail: section.summary
                                )
                            }
                        }
                    }
                } else {
                    ProfileEmptyText(text: "HAYF will build this after onboarding is complete.")
                }
            }
        }
    }
}

private struct ProfileEntryCard<Content: View>: View {
    let action: () -> Void
    let isDisabled: Bool
    @ViewBuilder let content: Content

    var body: some View {
        Button(action: action) {
            content
                .padding(18)
                .background(HAYFColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(HAYFColor.borderStrong, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

private struct ProfileCardHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(HAYFColor.primary)

                Text(subtitle)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(HAYFColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(HAYFColor.muted)
        }
    }
}

private struct ProfileDetailSheetView: View {
    let detail: ProfileDetailSheet
    let block: PlanActiveFitnessBlock?
    let strategy: ProfileAcceptedStrategy?
    let phases: [PlanFitnessBlockPhase]
    let targets: [PlanGoalTarget]
    let evaluations: [PlanGoalEvaluation]
    let blueprint: ProfileAthleteBlueprint?
    let reviewGoal: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            HAYFColor.neutral
                .ignoresSafeArea()

            switch detail {
            case .currentStrategy:
                CurrentStrategyDetailSheet(
                    block: block,
                    strategy: strategy,
                    phases: phases,
                    targets: targets,
                    evaluations: evaluations,
                    dismiss: { dismiss() },
                    reviewGoal: {
                        dismiss()
                        reviewGoal()
                    }
                )
            case .athleteBlueprint:
                AthleteBlueprintDetailSheet(
                    blueprint: blueprint,
                    dismiss: { dismiss() }
                )
            }
        }
    }
}

private struct CurrentStrategyDetailSheet: View {
    let block: PlanActiveFitnessBlock?
    let strategy: ProfileAcceptedStrategy?
    let phases: [PlanFitnessBlockPhase]
    let targets: [PlanGoalTarget]
    let evaluations: [PlanGoalEvaluation]
    let dismiss: () -> Void
    let reviewGoal: () -> Void

    private var strategyTargets: [PlanGoalTarget] {
        targets.filter { $0.targetScope == .strategy }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ProfileSheetHeader(
                overline: "CURRENT STRATEGY",
                title: block?.title ?? "Current strategy",
                dismiss: dismiss
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    if let block {
                        ProfileDetailSection(
                            title: block.kind == "consistency" ? "Current focus" : "Current goal",
                            text: ProfileDisplay.goalText(for: block)
                        )
                    }

                    ProfileDetailSection(
                        title: "Strategy read",
                        text: strategy?.read.profileNilIfEmpty ?? block?.context.planningRationale ?? "HAYF has not saved a strategy read yet."
                    )

                    if let context = strategy?.goalContextText {
                        ProfileDetailSection(title: "Goal context", text: context)
                    }

                    if let pillars = strategy?.pillars, !pillars.isEmpty {
                        ProfileTextListSection(title: "What HAYF will protect", items: pillars.map { "\($0.title): \($0.summary)" })
                    }

                    ProfileTargetGroup(
                        title: "Strategy targets",
                        emptyText: "Strategy targets will appear after planning finishes.",
                        targets: strategyTargets,
                        evaluations: evaluations
                    )

                    if phases.isEmpty {
                        if let rhythm = strategy?.operatingRhythm {
                            ProfileTextListSection(title: "Operating rhythm", lead: rhythm.summary, items: rhythm.anchors)
                        } else {
                            ProfileDetailSection(
                                title: "Operating rhythm",
                                text: "This strategy is rhythm-led, so HAYF will review repeatability instead of showing fake long-term phases."
                            )
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Phases and phase targets")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(HAYFColor.primary)

                            ForEach(phases) { phase in
                                ProfilePhaseCard(
                                    phase: phase,
                                    targets: targets.filter { $0.activePhaseID == phase.id },
                                    evaluations: evaluations
                                )
                            }
                        }
                    }
                }
                .padding(.bottom, 12)
            }

            Button(action: reviewGoal) {
                Text("Review goal")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(HAYFColor.primary)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 20)
    }
}

private struct AthleteBlueprintDetailSheet: View {
    let blueprint: ProfileAthleteBlueprint?
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ProfileSheetHeader(
                overline: "ATHLETE BLUEPRINT",
                title: "What HAYF knows",
                dismiss: dismiss
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    if let blueprint {
                        if let profileScores = blueprint.profileScores {
                            AthleteProfileChartCard(
                                scores: profileScores,
                                summary: blueprint.coachRead.summary,
                                layout: .profileDetail
                            )
                        }

                        ForEach(blueprint.profileScores != nil
                            ? Array(blueprint.detailSections.dropFirst())
                            : blueprint.detailSections) { section in
                            ProfileBlueprintDetailCard(section: section)
                        }
                    } else {
                        ProfileEmptyText(text: "HAYF will build this after onboarding is complete.")
                    }
                }
                .padding(.bottom, 12)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 20)
    }
}

private struct ProfileSheetHeader: View {
    let overline: String
    let title: String
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 7) {
                Text(overline)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(HAYFColor.muted)

                Text(title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(HAYFColor.primary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.78)
            }

            Spacer()

            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(HAYFColor.primary)
                    .frame(width: 36, height: 36)
                    .background(HAYFColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(HAYFColor.borderStrong, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
    }
}

private struct ProfileDetailSection: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(HAYFColor.primary)

            Text(text)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(HAYFColor.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ProfileTextListSection: View {
    let title: String
    var lead: String? = nil
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(HAYFColor.primary)

            if let lead, !lead.isEmpty {
                Text(lead)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(HAYFColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 9) {
                        Circle()
                            .fill(HAYFColor.orange)
                            .frame(width: 5, height: 5)
                            .padding(.top, 7)

                        Text(item)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(HAYFColor.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

private struct ProfileTargetGroup: View {
    let title: String
    let emptyText: String
    let targets: [PlanGoalTarget]
    let evaluations: [PlanGoalEvaluation]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(HAYFColor.primary)

            if targets.isEmpty {
                ProfileEmptyText(text: emptyText)
            } else {
                ForEach(targets) { target in
                    ProfileTargetLine(
                        target: target,
                        evaluation: ProfileDisplay.latestEvaluation(for: target, in: evaluations)
                    )
                }
            }
        }
    }
}

private struct ProfilePhaseCard: View {
    let phase: PlanFitnessBlockPhase
    let targets: [PlanGoalTarget]
    let evaluations: [PlanGoalEvaluation]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(phase.name.capitalized)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(HAYFColor.primary)

                Text(phase.objective)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(HAYFColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !phase.focus.isEmpty {
                Text(phase.focus.joined(separator: " "))
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(HAYFColor.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if targets.isEmpty {
                ProfileEmptyText(text: "Phase targets will appear after planning finishes.")
            } else {
                ForEach(targets) { target in
                    ProfileTargetLine(
                        target: target,
                        evaluation: ProfileDisplay.latestEvaluation(for: target, in: evaluations)
                    )
                }
            }
        }
        .padding(14)
        .background(HAYFColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(HAYFColor.borderStrong, lineWidth: 1)
        }
    }
}

private struct ProfileTargetLine: View {
    let target: PlanGoalTarget
    let evaluation: PlanGoalEvaluation?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: ProfileDisplay.targetIcon(for: target))
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(HAYFColor.primary)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 4) {
                Text(target.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(HAYFColor.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(ProfileDisplay.targetValueLine(for: target, evaluation: evaluation))
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(HAYFColor.muted)
            }

            Spacer(minLength: 8)

            Text((evaluation?.status ?? target.status).displayName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ProfileDisplay.statusColor(for: evaluation?.status ?? target.status))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(12)
        .background(HAYFColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(HAYFColor.borderStrong, lineWidth: 1)
        }
    }
}

private struct ProfileBlueprintDetailCard: View {
    let section: ProfileBlueprintSection

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: ProfileDisplay.blueprintIcon(for: section))
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(HAYFColor.orange)
                    .frame(width: 24)

                Text(section.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(HAYFColor.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                if let confidence = section.confidence {
                    Text(confidence)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(HAYFColor.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }

            Text(section.body?.profileNilIfEmpty ?? section.summary)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(HAYFColor.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let observationWindow = section.observationWindow {
                ProfilePill(text: observationWindow, tint: HAYFColor.secondary)
            }

            if !section.evidence.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(section.evidence.prefix(3), id: \.self) { evidence in
                        Text(evidence)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(HAYFColor.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if let caveat = section.caveat {
                Text(caveat)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(HAYFColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(HAYFColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(HAYFColor.borderStrong, lineWidth: 1)
        }
    }
}

private struct ProfileIconSummaryRow: View {
    let icon: String
    let text: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(HAYFColor.orange)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(HAYFColor.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(detail)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(HAYFColor.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct ProfilePill: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 9)
            .frame(height: 30)
            .background(HAYFColor.neutral)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(HAYFColor.border, lineWidth: 1)
            }
    }
}

private struct ProfileLoadingRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(HAYFColor.orange)

            Text(text)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(HAYFColor.muted)
        }
        .padding(.vertical, 8)
    }
}

private struct ProfileEmptyText: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(HAYFColor.muted)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 4)
    }
}

private struct ProfileInlineError: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(HAYFColor.primary)
            .lineLimit(3)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HAYFColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(HAYFColor.error.opacity(0.35), lineWidth: 1)
            }
    }
}

private struct ProfileAcceptedStrategy {
    let read: String
    let goalTitle: String?
    let goalSummary: String?
    let pillars: [ProfileStrategyTextItem]
    let operatingRhythm: ProfileOperatingRhythm?

    init(json: JSONValue) {
        let goalContext = json.profileValue("goalTargetContext")
        read = json.profileString("read")
        goalTitle = goalContext.profileString("title").profileNilIfEmpty
        goalSummary = goalContext.profileString("summary").profileNilIfEmpty
        pillars = json.profileArray("pillars").map { item in
            ProfileStrategyTextItem(
                title: item.profileString("title"),
                summary: item.profileString("summary")
            )
        }
        let rhythm = json.profileValue("operatingRhythm")
        operatingRhythm = rhythm.profileIsEmpty ? nil : ProfileOperatingRhythm(json: rhythm)
    }

    var goalContextText: String? {
        [goalTitle, goalSummary]
            .compactMap { $0?.profileNilIfEmpty }
            .joined(separator: "\n")
            .profileNilIfEmpty
    }
}

private struct ProfileStrategyTextItem {
    let title: String
    let summary: String
}

private struct ProfileOperatingRhythm {
    let summary: String
    let anchors: [String]

    init(json: JSONValue) {
        summary = json.profileString("summary")
        anchors = json.profileArray("anchors").compactMap(\.profileStringValue)
    }
}

private enum ProfileDisplay {
    static func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        let initials = parts.prefix(2).compactMap(\.first).map(String.init).joined()
        return initials.isEmpty ? "H" : initials.uppercased()
    }

    static func locationLine(profile: StoredAccountProfile, userEmail: String?) -> String {
        if profile.mainCity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return userEmail ?? "Account"
        }

        return profile.mainCity
    }

    static func goalText(for block: PlanActiveFitnessBlock) -> String {
        if let goalText = block.goalText?.trimmingCharacters(in: .whitespacesAndNewlines),
           !goalText.isEmpty {
            return goalText
        }

        return block.title
    }

    static func reviewText(for block: PlanActiveFitnessBlock) -> String {
        let weeks = max(1, Int(ceil(Double(block.reviewCadenceDays) / 7.0)))
        return "Review \(weeks)w"
    }

    static func goalRoleText(for block: PlanActiveFitnessBlock?) -> String {
        guard let block else {
            return "HAYF has not created an active fitness context yet."
        }

        switch block.kind {
        case "consistency":
            return "This focus keeps training repeatable without forcing a performance target."
        case "specific_goal", "goal_discovery_chosen":
            return "This is the durable goal HAYF turns into the strategy, phases, targets, weekly rhythm, and workout recommendations."
        default:
            return "This is the current fitness context HAYF uses to shape planning and recommendations."
        }
    }

    static func latestEvaluation(for target: PlanGoalTarget, in evaluations: [PlanGoalEvaluation]) -> PlanGoalEvaluation? {
        evaluations.first { $0.goalTargetID == target.id }
    }

    static func targetValueLine(for target: PlanGoalTarget, evaluation: PlanGoalEvaluation?) -> String {
        if case let .object(rule) = target.evaluationRule,
           case let .string(displayValue)? = rule["displayValue"],
           !displayValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return displayValue
        }

        let unit = target.unit ?? evaluation?.unit ?? ""
        let current = evaluation?.currentValue
        let targetValue = evaluation?.targetValue ?? target.targetValue

        if let current, let targetValue {
            if target.direction == "decrease" {
                return "\(formatted(current)) -> \(formatted(targetValue))\(unitSuffix(unit))"
            }

            return "\(formatted(current)) / \(formatted(targetValue))\(unitSuffix(unit))"
        }

        if let baseline = target.baselineValue, let targetValue {
            return "\(formatted(baseline)) -> \(formatted(targetValue))\(unitSuffix(unit))"
        }

        if let targetValue {
            return "Target \(formatted(targetValue))\(unitSuffix(unit))"
        }

        if let description = target.description?.profileNilIfEmpty {
            return description
        }

        return "Needs more data"
    }

    static func statusColor(for status: PlanGoalStatus?) -> Color {
        switch status {
        case .onTrack, .achieved, .notStarted:
            return HAYFColor.primary
        case .lagging:
            return HAYFColor.error
        case .needsReview:
            return HAYFColor.orange
        case nil:
            return HAYFColor.secondary
        }
    }

    static func targetIcon(for target: PlanGoalTarget) -> String {
        let text = "\(target.metricKey ?? "") \(target.metricCategory ?? "") \(target.title)".lowercased()

        if text.contains("body") || text.contains("weight") || text.contains("fat") {
            return "scalemass"
        } else if text.contains("run") {
            return "figure.run"
        } else if text.contains("cycle") || text.contains("bike") {
            return "bicycle"
        } else if text.contains("strength") || text.contains("upper") {
            return "dumbbell"
        } else if text.contains("step") || text.contains("activity") {
            return "figure.walk"
        } else {
            return "target"
        }
    }

    static func blueprintIcon(for section: ProfileBlueprintSection) -> String {
        switch section.id {
        case "coach_read":
            return "sparkles"
        case "athlete_archetype":
            return "person.text.rectangle"
        case "current_training_state":
            return "waveform.path.ecg"
        case "physical_baseline":
            return "scalemass"
        case "goal_fit":
            return "target"
        default:
            return "list.bullet.rectangle"
        }
    }

    private static func formatted(_ value: Double) -> String {
        if abs(value) >= 100 {
            return "\(Int(value.rounded()))"
        }

        if value.rounded() == value {
            return "\(Int(value))"
        }

        return String(format: "%.1f", value)
    }

    private static func unitSuffix(_ unit: String) -> String {
        let trimmed = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        if trimmed == "%" {
            return "%"
        }

        return " \(trimmed)"
    }
}

#Preview {
    ProfileScreenView(
        accountProfile: StoredAccountProfile(
            id: UUID(),
            name: "Daniel Loureiro",
            birthdate: "1990-01-01",
            physiologyReference: "male",
            mainCity: "Lisbon",
            profilePhotoPath: nil,
            profilePhotoURL: nil
        ),
        userEmail: "daniel@example.com",
        editProfile: {},
        reviewGoal: {},
        signOut: {}
    )
}
