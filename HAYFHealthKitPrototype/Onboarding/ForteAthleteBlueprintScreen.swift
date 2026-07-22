import SwiftUI

enum AthleteProfileDimensionKey: String, Codable, CaseIterable, Identifiable {
    case consistency
    case momentum
    case strength
    case trainingBase = "training_base"
    case endurance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .consistency: return "Consistency"
        case .momentum: return "Momentum"
        case .strength: return "Strength"
        case .trainingBase: return "Training base"
        case .endurance: return "Endurance"
        }
    }
}

struct AthleteProfileScoreComponent: Codable, Equatable {
    let key: String
    let value: Int?
    let weight: Double
    let status: String
    let evidenceIds: [String]
}

struct AthleteProfileDimension: Codable, Equatable, Identifiable {
    let key: AthleteProfileDimensionKey
    let score: Int?
    let status: String
    let confidence: String
    let components: [AthleteProfileScoreComponent]
    let evidenceIds: [String]

    var id: AthleteProfileDimensionKey { key }
    var isAvailable: Bool {
        status == "available" && score.map { (0...100).contains($0) } == true
    }

    var displayScore: Int? {
        guard isAvailable, let score else { return nil }
        return (score + 4) / 10
    }

    var displayValue: String {
        displayScore.map(String.init) ?? "—"
    }

    var accessibilityValue: String {
        isAvailable ? "\(displayValue) out of 10" : "Not enough evidence"
    }

    var accessibilityDescription: String {
        "\(key.title), \(accessibilityValue.lowercased())"
    }
}

struct AthleteProfileSourceSummary: Codable, Equatable {
    let importedWorkoutCount: Int
}

struct AthleteProfileScores: Codable, Equatable {
    let schemaVersion: String
    let scoreVersion: String
    let evaluatedAt: String
    let dimensions: [AthleteProfileDimension]
    let sourceSummary: AthleteProfileSourceSummary

    var orderedDimensions: [AthleteProfileDimension] {
        AthleteProfileDimensionKey.allCases.map { key in
            dimensions.first { $0.key == key } ?? AthleteProfileDimension(
                key: key,
                score: nil,
                status: "unavailable",
                confidence: "insufficient",
                components: [],
                evidenceIds: []
            )
        }
    }

    var availableCount: Int {
        orderedDimensions.filter(\.isAvailable).count
    }

    var presentation: AthleteProfilePresentation {
        availableCount == 5 ? .complete : .partial
    }

    var jsonValue: JSONValue? {
        try? JSONValue.isoEncoded(self)
    }

    static func decode(jsonValue: JSONValue) -> AthleteProfileScores? {
        guard let data = try? JSONEncoder().encode(jsonValue) else { return nil }
        guard let scores = try? JSONDecoder().decode(AthleteProfileScores.self, from: data),
              scores.schemaVersion == "athlete-profile-scores.v1",
              scores.scoreVersion == "profile-radar-v1.2.0",
              scores.dimensions.map(\.key) == AthleteProfileDimensionKey.allCases,
              scores.dimensions.allSatisfy({ dimension in
                  dimension.status == "unavailable" ? dimension.score == nil : dimension.isAvailable
              }) else { return nil }
        return scores
    }
}

enum AthleteProfilePresentation: Equatable {
    case complete
    case partial
}

enum AthleteProfileCardLayout: Equatable {
    case onboarding
    case profileCompact
    case profileDetail

    var chartHeight: CGFloat {
        switch self {
        case .onboarding: return 292
        case .profileCompact: return 220
        case .profileDetail: return 268
        }
    }

    var cornerRadius: CGFloat {
        self == .onboarding ? 24 : 12
    }
}

struct AthleteProfileChartCard: View {
    let scores: AthleteProfileScores
    let summary: String
    var layout: AthleteProfileCardLayout = .onboarding

    var body: some View {
        VStack(alignment: .leading, spacing: layout == .profileCompact ? 12 : 16) {
            Text("YOUR ATHLETE PROFILE")
                .font(.system(size: 11, weight: .semibold))
                .tracking(2.0)
                .foregroundStyle(ForteColor.ink)

            AthleteRadarChart(dimensions: scores.orderedDimensions)
                .frame(height: layout.chartHeight)

            Rectangle()
                .fill(ForteColor.borderSubtle)
                .frame(height: 1)

            Text(summary)
                .font(layout == .profileCompact
                    ? .system(size: 14, weight: .regular)
                    : ForteTypography.editorial(size: 17, relativeTo: .body))
                .lineSpacing(layout == .profileCompact ? 3 : 5)
                .foregroundStyle(ForteColor.ink)
                .lineLimit(layout == .profileCompact ? 2 : nil)
                .fixedSize(horizontal: false, vertical: layout != .profileCompact)

            HStack(spacing: 8) {
                Image(systemName: "externaldrive.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ForteColor.indigoDeep)
                    .frame(width: 28, height: 28)
                    .background(ForteColor.indigoSoft)
                    .clipShape(Circle())
                    .accessibilityHidden(true)

                Text(sourceText)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(ForteColor.inkMuted)
            }

        }
        .padding(layout == .profileCompact ? 14 : 18)
        .background(ForteColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: layout.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: layout.cornerRadius, style: .continuous)
                .stroke(ForteColor.borderSubtle.opacity(0.9), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(layout == .onboarding ? 0.055 : 0), radius: 16, y: 9)
    }

    private var sourceText: String {
        let count = scores.sourceSummary.importedWorkoutCount
        return "Based on \(count) imported workouts"
    }
}

private struct AthleteRadarChart: View {
    let dimensions: [AthleteProfileDimension]

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2 + 4)
            let radius = min(geometry.size.width * 0.30, geometry.size.height * 0.31)

            ZStack {
                radarGrid(center: center, radius: radius)
                    .stroke(ForteColor.borderSubtle, lineWidth: 1)

                radarSpokes(center: center, radius: radius)
                    .stroke(ForteColor.borderSubtle.opacity(0.8), lineWidth: 1)

                if dimensions.allSatisfy(\.isAvailable) {
                    radarPolygon(center: center, radius: radius)
                        .fill(ForteColor.indigo.opacity(0.16))
                    radarPolygon(center: center, radius: radius)
                        .stroke(ForteColor.indigo, lineWidth: 2)
                } else {
                    partialRadar(center: center, radius: radius)
                        .stroke(ForteColor.indigo, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }

                ForEach(Array(dimensions.enumerated()), id: \.element.id) { index, dimension in
                    if let score = dimension.score, dimension.isAvailable {
                        Circle()
                            .fill(ForteColor.indigo)
                            .frame(width: 9, height: 9)
                            .position(point(index: index, value: CGFloat(score) / 100, center: center, radius: radius))
                            .accessibilityHidden(true)
                    }

                    dimensionLabel(dimension)
                        .frame(width: labelWidth(for: dimension.key))
                        .position(labelPoint(index: index, center: center, radius: radius))
                }
            }
        }
    }

    private func dimensionLabel(_ dimension: AthleteProfileDimension) -> some View {
        VStack(spacing: 2) {
            Text(dimension.key.title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.7)
                .foregroundStyle(ForteColor.ink)
                .multilineTextAlignment(.center)

            Text(dimension.displayValue)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(dimension.isAvailable ? ForteColor.indigoDeep : ForteColor.inkMuted)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(dimension.key.title)
        .accessibilityValue(dimension.accessibilityValue)
    }

    private func radarGrid(center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        for ring in 1...5 {
            let scale = CGFloat(ring) / 5
            let points = (0..<5).map { point(index: $0, value: scale, center: center, radius: radius) }
            path.move(to: points[0])
            points.dropFirst().forEach { path.addLine(to: $0) }
            path.closeSubpath()
        }
        return path
    }

    private func radarSpokes(center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        for index in 0..<5 {
            path.move(to: center)
            path.addLine(to: point(index: index, value: 1, center: center, radius: radius))
        }
        return path
    }

    private func radarPolygon(center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        let points = dimensions.enumerated().map { index, dimension in
            point(index: index, value: CGFloat(dimension.score ?? 0) / 100, center: center, radius: radius)
        }
        guard let first = points.first else { return path }
        path.move(to: first)
        points.dropFirst().forEach { path.addLine(to: $0) }
        path.closeSubpath()
        return path
    }

    private func partialRadar(center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        guard dimensions.count == 5 else { return path }
        for index in 0..<5 {
            let next = (index + 1) % 5
            guard dimensions[index].isAvailable,
                  dimensions[next].isAvailable,
                  let score = dimensions[index].score,
                  let nextScore = dimensions[next].score else { continue }
            path.move(to: point(index: index, value: CGFloat(score) / 100, center: center, radius: radius))
            path.addLine(to: point(index: next, value: CGFloat(nextScore) / 100, center: center, radius: radius))
        }
        return path
    }

    private func point(index: Int, value: CGFloat, center: CGPoint, radius: CGFloat) -> CGPoint {
        let angle = -CGFloat.pi / 2 + CGFloat(index) * (2 * CGFloat.pi / 5)
        return CGPoint(
            x: center.x + cos(angle) * radius * value,
            y: center.y + sin(angle) * radius * value
        )
    }

    private func labelPoint(index: Int, center: CGPoint, radius: CGFloat) -> CGPoint {
        let multiplier: CGFloat = index == 0 ? 1.43 : 1.46
        return point(index: index, value: multiplier, center: center, radius: radius)
    }

    private func labelWidth(for key: AthleteProfileDimensionKey) -> CGFloat {
        key == .trainingBase ? 96 : 78
    }
}

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
    let profileScores: AthleteProfileScores?
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

                        if let profileScores {
                            AthleteProfileChartCard(
                                scores: profileScores,
                                summary: coachRead
                            )
                        } else {
                            ForteAIReadbackCard(
                                label: "COACH'S READ",
                                text: coachRead,
                                footer: "Built from your answers and available health data"
                            )
                        }

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
                ForteBlueprintSnapshotRow(
                    item: item,
                    palette: .cycling(index)
                )

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
}

private struct ForteBlueprintSnapshotRow: View {
    let item: ForteBlueprintSnapshotItem
    let palette: ForteReviewIconPalette

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            snapshotIcon

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

    @ViewBuilder
    private var snapshotIcon: some View {
        if let assetName = snapshotAssetName {
            Image(assetName)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 48, height: 48)
                .accessibilityHidden(true)
        } else {
            ForteReviewIconBadge(
                systemName: item.systemImage,
                palette: palette,
                size: 48,
                iconSize: 18
            )
        }
    }

    private var snapshotAssetName: String? {
        switch item.label {
        case "Athlete type": return "ForteBlueprintAthleteType"
        case "Current state": return "ForteBlueprintCurrentState"
        case "Physical baseline": return "ForteSummaryBodyBaseline"
        default: return nil
        }
    }
}

private struct ForteBlueprintHistoryList: View {
    let items: [ForteBlueprintHistoryItem]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HStack(alignment: .top, spacing: 12) {
                    Image("ForteHealthTrainingHistory")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 48, height: 48)
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
}

private struct ForteBlueprintGoalFitCard: View {
    let goalFit: ForteBlueprintGoalFit

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image("ForteStrategyTarget")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 48, height: 48)
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
                    palette: .teal,
                    items: goalFit.supports
                )
            }

            if !goalFit.gaps.isEmpty {
                ForteBlueprintSignalGroup(
                    title: "What to account for",
                    systemImage: "minus",
                    palette: .ochre,
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
    let palette: ForteReviewIconPalette
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
                        .foregroundStyle(palette.foreground)
                        .frame(width: 18, height: 18)
                        .background(palette.background)
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
