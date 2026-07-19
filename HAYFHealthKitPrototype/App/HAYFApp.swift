import SwiftUI

@main
struct HAYFApp: App {
    var body: some Scene {
        WindowGroup {
            #if FORTE_DEV
            if let previewIntent = ForteInfrastructurePreviewLaunch.intent {
                ForteInfrastructurePreviewHost(intent: previewIntent)
            } else if let previewIntent = ForteModalityPreviewLaunch.intent {
                ForteModalityPreviewHost(intent: previewIntent)
            } else if let previewIntent = ForteIntentPreviewLaunch.intent {
                ForteIntentPreviewHost(initialIntent: previewIntent)
            } else if ForteIntentPreviewLaunch.showsUnselectedIntent {
                ForteIntentPreviewHost(initialIntent: nil)
            } else {
                AppRootView()
            }
            #else
            AppRootView()
            #endif
        }
    }
}

#if FORTE_DEV
private enum ForteInfrastructurePreviewLaunch {
    private static let selectedArgumentPrefix = "--forte-infrastructure-preview="

    static var intent: OnboardingIntent? {
        guard let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(selectedArgumentPrefix) }) else {
            return nil
        }

        return OnboardingIntent(rawValue: String(argument.dropFirst(selectedArgumentPrefix.count)))
    }
}

private enum ForteModalityPreviewLaunch {
    private static let selectedArgumentPrefix = "--forte-modality-preview="

    static var intent: OnboardingIntent? {
        guard let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(selectedArgumentPrefix) }) else {
            return nil
        }

        return OnboardingIntent(rawValue: String(argument.dropFirst(selectedArgumentPrefix.count)))
    }
}

private enum ForteIntentPreviewLaunch {
    private static let unselectedArgument = "--forte-intent-preview"
    private static let selectedArgumentPrefix = "--forte-intent-preview="

    static var showsUnselectedIntent: Bool {
        ProcessInfo.processInfo.arguments.contains(unselectedArgument)
    }

    static var intent: OnboardingIntent? {
        guard let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(selectedArgumentPrefix) }) else {
            return nil
        }

        return OnboardingIntent(rawValue: String(argument.dropFirst(selectedArgumentPrefix.count)))
    }
}

private struct ForteInfrastructurePreviewHost: View {
    let intent: OnboardingIntent
    private let options: [InfrastructureAccess] = [
        .gym,
        .indoorBike,
        .outdoorBike,
        .outdoorRoutes,
        .treadmill,
        .homeWeights
    ]
    @State private var selectedOptions: Set<InfrastructureAccess> = [.gym, .outdoorRoutes]
    @State private var didExit = false

    var body: some View {
        if didExit {
            Text("Onboarding closed")
                .accessibilityIdentifier("forte.infrastructure.closed")
        } else {
            ForteInfrastructureScreen(
                options: options,
                selectedOptions: selectedOptions,
                progressStep: OnboardingStep.infrastructure.activeSegments(for: intent),
                totalSteps: OnboardingStep.totalSegments(for: intent),
                onToggle: toggle,
                onBack: {},
                onExit: { didExit = true },
                onContinue: {}
            )
        }
    }

    private func toggle(_ option: InfrastructureAccess) {
        if selectedOptions.contains(option) {
            selectedOptions.remove(option)
        } else {
            selectedOptions.insert(option)
        }
    }
}

private struct ForteModalityPreviewHost: View {
    let intent: OnboardingIntent
    @State private var selectedOptions: [TrainingOption] = [.cycling, .strength, .running]
    @State private var didExit = false

    var body: some View {
        if didExit {
            Text("Onboarding closed")
                .accessibilityIdentifier("forte.modality.closed")
        } else {
            ForteModalityScreen(
                selectedOptions: selectedOptions,
                progressStep: OnboardingStep.options.activeSegments(for: intent),
                totalSteps: OnboardingStep.totalSegments(for: intent),
                onToggle: toggle,
                onBack: {},
                onExit: { didExit = true },
                onContinue: {}
            )
        }
    }

    private func toggle(_ option: TrainingOption) {
        guard option.isOnboardingEnabled else { return }
        if let index = selectedOptions.firstIndex(of: option) {
            selectedOptions.remove(at: index)
        } else {
            selectedOptions.append(option)
        }
    }
}

private struct ForteIntentPreviewHost: View {
    let initialIntent: OnboardingIntent?
    @State private var didExit = false

    var body: some View {
        if didExit {
            Text("Onboarding closed")
                .accessibilityIdentifier("forte.intent.closed")
        } else {
            OnboardingFlowView(
                physiologyReference: .male,
                birthdate: Calendar.current.date(byAdding: .year, value: -30, to: .now) ?? .now,
                onboardingProfileStore: OnboardingProfileStore(),
                initialIntent: initialIntent,
                onExit: { didExit = true }
            ) {}
        }
    }
}
#endif
