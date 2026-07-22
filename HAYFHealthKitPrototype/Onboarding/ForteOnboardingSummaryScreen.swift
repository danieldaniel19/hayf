import SwiftUI

enum ForteSummaryAnswerRole: String, CaseIterable, Equatable {
    case training
    case access
    case anchor
    case availability
    case capacity
    case risks
    case injuries
    case bodyBaseline
    case support
    case floor
    case goal
    case timeframe
    case experience
    case tradeoff
    case direction
    case challenge
    case avoidance
    case intensity

    var assetName: String {
        switch self {
        case .training: return "ForteSummaryTraining"
        case .access: return "ForteSummaryAccess"
        case .anchor: return "ForteSummaryAnchor"
        case .availability: return "ForteSummaryAvailability"
        case .capacity: return "ForteSummaryCapacity"
        case .risks: return "ForteSummaryRisks"
        case .injuries: return "ForteSummaryInjuries"
        case .bodyBaseline: return "ForteSummaryBodyBaseline"
        case .support: return "ForteSummarySupport"
        case .floor: return "ForteSummaryFloor"
        case .goal: return "ForteStrategyGoalSignal"
        case .timeframe: return "ForteStrategyCadence"
        case .experience: return "ForteHealthTrainingHistory"
        case .tradeoff: return "ForteStrategyTradeoff"
        case .direction: return "ForteStrategyDriver"
        case .challenge: return "ForteStrategyTarget"
        case .avoidance: return "ForteStrategyProtect"
        case .intensity: return "ForteStrategyPriority"
        }
    }
}

struct ForteSummaryAnswer: Identifiable, Equatable {
    let role: ForteSummaryAnswerRole
    let label: String
    let systemImage: String
    let values: [String]

    var id: String { label }
}

struct ForteOnboardingSummaryScreen: View {
    let readback: String
    let answers: [ForteSummaryAnswer]
    let progressStep: Int
    let totalSteps: Int
    let onConfirm: () -> Void
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
                            label: "FORTE READBACK",
                            text: readback,
                            footer: "Built from your onboarding answers"
                        )

                        Text("YOUR ANSWERS")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(2.6)
                            .foregroundStyle(ForteColor.inkMuted)
                            .padding(.top, 28)
                            .padding(.bottom, 12)

                        ForteSummaryAnswerList(answers: answers)
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
            Text("ONBOARDING")
                .font(.system(size: 11, weight: .semibold))
                .tracking(3.4)
                .foregroundStyle(ForteColor.indigoDeep)

            Text("Here's what\nForte understood.")
                .font(ForteTypography.editorial(size: 32, relativeTo: .largeTitle))
                .tracking(-0.4)
                .foregroundStyle(ForteColor.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)

            Text("Check this readback against\nthe answers you gave.")
                .font(.system(size: 15, weight: .regular))
                .lineSpacing(5)
                .foregroundStyle(ForteColor.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .padding(.bottom, 24)
        }
    }

    private var bottomActions: some View {
        VStack(spacing: 10) {
            Button(action: onConfirm) {
                HStack(spacing: 12) {
                    Text("Looks right")
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
            .accessibilityHint("Accepts the readback and continues onboarding.")

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

struct ForteAIReadbackCard: View {
    let label: String
    let text: String
    let footer: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                ForteReadbackMark()

                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(2.1)
                    .foregroundStyle(ForteColor.indigoDeep)
            }

            Text(text)
                .font(ForteTypography.editorial(size: 17, relativeTo: .body))
                .lineSpacing(6)
                .foregroundStyle(ForteColor.ink)
                .fixedSize(horizontal: false, vertical: true)

            Rectangle()
                .fill(ForteColor.indigoDeep.opacity(0.10))
                .frame(height: 1)

            HStack(spacing: 7) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ForteColor.indigo)

                Text(footer)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ForteColor.inkMuted)
            }
        }
        .padding(20)
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

private struct ForteReadbackMark: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(ForteColor.indigoSoft)
                .frame(width: 34, height: 34)

            Capsule()
                .fill(ForteColor.indigoDeep)
                .frame(width: 19, height: 4)
                .rotationEffect(.degrees(-24))

            Circle()
                .fill(Color.white)
                .frame(width: 11, height: 11)
                .offset(x: -5, y: -3)
                .shadow(color: Color.black.opacity(0.09), radius: 2, y: 1)

            Circle()
                .fill(Color(red: 0.58, green: 0.66, blue: 0.63))
                .frame(width: 7, height: 7)
                .offset(x: 7, y: 7)
        }
        .accessibilityHidden(true)
    }
}

private struct ForteSummaryAnswerList: View {
    let answers: [ForteSummaryAnswer]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(answers.enumerated()), id: \.element.id) { index, answer in
                ForteSummaryAnswerRow(
                    answer: answer,
                    palette: .cycling(index)
                )

                if index < answers.count - 1 {
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

private struct ForteSummaryAnswerRow: View {
    let answer: ForteSummaryAnswer
    let palette: ForteReviewIconPalette

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            reviewIcon

            VStack(alignment: .leading, spacing: 5) {
                Text(answer.label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ForteColor.ink)

                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(answer.values.enumerated()), id: \.offset) { index, value in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            if answer.values.count > 1 {
                                Text("\(index + 1).")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(ForteColor.indigoDeep)
                            }

                            Text(value)
                                .font(.system(size: 14, weight: .regular))
                                .lineSpacing(3)
                                .foregroundStyle(ForteColor.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var reviewIcon: some View {
        Image(answer.role.assetName)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: 48, height: 48)
            .accessibilityHidden(true)
    }
}

struct ForteSummaryHeaderButton: View {
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
