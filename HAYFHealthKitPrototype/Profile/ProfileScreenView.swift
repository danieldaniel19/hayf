import SwiftUI

struct ProfileScreenView: View {
    let accountProfile: StoredAccountProfile
    let userEmail: String?
    let openSettings: () -> Void
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
                        openSettings: openSettings
                    )

                    CurrentGoalCard(
                        block: store.activeBlock,
                        primaryTarget: primaryTarget,
                        evaluation: primaryEvaluation,
                        isLoading: store.isLoading && !didLoad,
                        openDetail: {
                            selectedDetail = .currentGoal
                        }
                    )

                    FitnessProfileCard(
                        insights: store.historyInsights,
                        isLoading: store.isLoading && !didLoad,
                        openDetail: {
                            selectedDetail = .fitnessProfile
                        }
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
                targets: store.goalTargets,
                evaluations: store.goalEvaluations,
                insights: store.historyInsights
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var primaryTarget: PlanGoalTarget? {
        store.goalTargets.first { $0.targetKind == .primary }
    }

    private var primaryEvaluation: PlanGoalEvaluation? {
        guard let primaryTarget else { return nil }
        return ProfileDisplay.latestEvaluation(for: primaryTarget, in: store.goalEvaluations)
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
    case currentGoal
    case fitnessProfile

    var id: String {
        switch self {
        case .currentGoal:
            return "current-goal"
        case .fitnessProfile:
            return "fitness-profile"
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
    let openSettings: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            ProfileAvatarView(
                name: profile.name,
                photoURL: profilePhotoURL
            )

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

            Button(action: openSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 19, weight: .regular))
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
            .accessibilityLabel("Open profile settings")
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

private struct CurrentGoalCard: View {
    let block: PlanActiveFitnessBlock?
    let primaryTarget: PlanGoalTarget?
    let evaluation: PlanGoalEvaluation?
    let isLoading: Bool
    let openDetail: () -> Void

    var body: some View {
        Button(action: openDetail) {
            VStack(alignment: .leading, spacing: 15) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(title)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(HAYFColor.primary)

                        Text(subtitle)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(HAYFColor.muted)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(HAYFColor.muted)
                }

                if isLoading {
                    ProfileLoadingRow(text: "Loading current goal")
                } else if let block {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(ProfileDisplay.goalText(for: block))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(HAYFColor.primary)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 8) {
                            ProfilePill(text: statusText, tint: ProfileDisplay.statusColor(for: evaluation?.status ?? primaryTarget?.status))
                            ProfilePill(text: ProfileDisplay.reviewText(for: block), tint: HAYFColor.secondary)
                        }
                    }
                } else {
                    ProfileEmptyText(text: "No active goal is available yet.")
                }
            }
            .padding(18)
            .background(HAYFColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(HAYFColor.borderStrong, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(block == nil && !isLoading)
    }

    private var title: String {
        guard let block else { return "Current goal" }
        return block.kind == "consistency" ? "Current focus" : "Current goal"
    }

    private var subtitle: String {
        guard let block else { return "What HAYF is working from." }
        return block.kind == "consistency" ? "Your post-onboarding rhythm." : "Created during onboarding · Active now"
    }

    private var statusText: String {
        if let status = evaluation?.status ?? primaryTarget?.status {
            return status.displayName
        }

        return "Active"
    }
}

private struct FitnessProfileCard: View {
    let insights: [FitnessHistoryInsight]
    let isLoading: Bool
    let openDetail: () -> Void

    private var visibleInsights: [FitnessHistoryInsight] {
        Array(insights.prefix(4))
    }

    var body: some View {
        Button(action: openDetail) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Fitness profile")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(HAYFColor.primary)

                        Text("What HAYF knows from your training history.")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(HAYFColor.muted)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(HAYFColor.muted)
                }

                if isLoading {
                    ProfileLoadingRow(text: "Loading fitness profile")
                } else if visibleInsights.isEmpty {
                    ProfileEmptyText(text: "HAYF will build this after the next Health sync.")
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(visibleInsights) { insight in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: ProfileDisplay.insightIcon(for: insight))
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundStyle(HAYFColor.orange)
                                    .frame(width: 22)

                                Text(insight.summary)
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundStyle(HAYFColor.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        ProfilePill(text: ProfileDisplay.freshnessText(from: insights), tint: HAYFColor.secondary)
                            .padding(.top, 2)
                    }
                }
            }
            .padding(18)
            .background(HAYFColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(HAYFColor.borderStrong, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct ProfileDetailSheetView: View {
    let detail: ProfileDetailSheet
    let block: PlanActiveFitnessBlock?
    let targets: [PlanGoalTarget]
    let evaluations: [PlanGoalEvaluation]
    let insights: [FitnessHistoryInsight]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            HAYFColor.neutral
                .ignoresSafeArea()

            switch detail {
            case .currentGoal:
                CurrentGoalDetailSheet(
                    block: block,
                    targets: targets,
                    evaluations: evaluations,
                    dismiss: { dismiss() }
                )
            case .fitnessProfile:
                FitnessProfileDetailSheet(
                    insights: insights,
                    dismiss: { dismiss() }
                )
            }
        }
    }
}

private struct CurrentGoalDetailSheet: View {
    let block: PlanActiveFitnessBlock?
    let targets: [PlanGoalTarget]
    let evaluations: [PlanGoalEvaluation]
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ProfileSheetHeader(
                overline: block?.kind == "consistency" ? "CURRENT FOCUS" : "CURRENT GOAL",
                title: block.map(ProfileDisplay.goalText(for:)) ?? "Current goal",
                dismiss: dismiss
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    ProfileDetailSection(
                        title: "Role",
                        text: ProfileDisplay.goalRoleText(for: block)
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Targets HAYF watches")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(HAYFColor.primary)

                        if targets.isEmpty {
                            ProfileEmptyText(text: "Targets will appear after the next sync.")
                        } else {
                            ForEach(targets.prefix(5)) { target in
                                ProfileTargetLine(
                                    target: target,
                                    evaluation: ProfileDisplay.latestEvaluation(for: target, in: evaluations)
                                )
                            }
                        }
                    }

                    ProfileDetailSection(
                        title: "Changing this",
                        text: "Use Review / Change goal when the underlying goal is no longer right. HAYF should update the current block and targets instead of creating a parallel goal."
                    )
                }
                .padding(.bottom, 12)
            }

            Button(action: {}) {
                Text("Review / Change goal")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(HAYFColor.primary.opacity(0.55))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(true)
            .accessibilityLabel("Review or change goal coming soon")
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 20)
    }
}

private struct FitnessProfileDetailSheet: View {
    let insights: [FitnessHistoryInsight]
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ProfileSheetHeader(
                overline: "FITNESS PROFILE",
                title: "What HAYF knows",
                dismiss: dismiss
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    if insights.isEmpty {
                        ProfileEmptyText(text: "HAYF will build this after the next Health sync.")
                    } else {
                        ForEach(insights) { insight in
                            ProfileInsightDetailCard(insight: insight)
                        }
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

                Text(ProfileDisplay.targetValueLine(for: target, evaluation: evaluation))
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(HAYFColor.muted)
            }

            Spacer(minLength: 8)

            Text((evaluation?.status ?? target.status).displayName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ProfileDisplay.statusColor(for: evaluation?.status ?? target.status))
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

private struct ProfileInsightDetailCard: View {
    let insight: FitnessHistoryInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: ProfileDisplay.insightIcon(for: insight))
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(HAYFColor.orange)
                    .frame(width: 24)

                Text(insight.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(HAYFColor.primary)

                Spacer(minLength: 8)

                Text(insight.confidence.capitalized)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(HAYFColor.muted)
            }

            Text(insight.summary)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(HAYFColor.secondary)
                .fixedSize(horizontal: false, vertical: true)
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

private struct ProfilePill: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(tint)
            .lineLimit(1)
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
            return "This is the durable goal HAYF turns into training targets, weekly rhythm, and workout recommendations."
        default:
            return "This is the current fitness context HAYF uses to shape planning and recommendations."
        }
    }

    static func latestEvaluation(
        for target: PlanGoalTarget,
        in evaluations: [PlanGoalEvaluation]
    ) -> PlanGoalEvaluation? {
        evaluations.first { $0.goalTargetID == target.id }
    }

    static func targetValueLine(for target: PlanGoalTarget, evaluation: PlanGoalEvaluation?) -> String {
        let unit = target.unit ?? evaluation?.unit ?? ""
        let current = evaluation?.currentValue
        let targetValue = evaluation?.targetValue ?? target.targetValue

        if let current, let targetValue {
            if target.direction == "decrease" {
                return "\(formatted(current)) → \(formatted(targetValue))\(unitSuffix(unit))"
            }

            return "\(formatted(current)) / \(formatted(targetValue))\(unitSuffix(unit))"
        }

        if let baseline = target.baselineValue, let targetValue {
            return "\(formatted(baseline)) → \(formatted(targetValue))\(unitSuffix(unit))"
        }

        if let targetValue {
            return "Target \(formatted(targetValue))\(unitSuffix(unit))"
        }

        return "Needs more data"
    }

    static func statusColor(for status: PlanGoalStatus?) -> Color {
        switch status {
        case .onTrack, .achieved:
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

    static func insightIcon(for insight: FitnessHistoryInsight) -> String {
        switch insight.category {
        case "identity":
            return "person.text.rectangle"
        case "consistency":
            return "calendar"
        case "seasonality":
            return "sun.max"
        case "performance":
            return "speedometer"
        case "balance":
            return "dumbbell"
        case "body":
            return "heart"
        default:
            return "sparkle"
        }
    }

    static func freshnessText(from insights: [FitnessHistoryInsight]) -> String {
        guard let latest = insights.map(\.updatedAt).max() else {
            return "Waiting for sync"
        }

        if latest.count >= 10 {
            return "Updated \(String(latest.prefix(10)))"
        }

        return "Updated recently"
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
            mainCity: "Lisbon",
            profilePhotoPath: nil,
            profilePhotoURL: nil
        ),
        userEmail: "daniel@example.com",
        openSettings: {},
        signOut: {}
    )
}
