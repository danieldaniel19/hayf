import SwiftUI

@main
struct HAYFApp: App {
    var body: some Scene {
        WindowGroup {
            #if FORTE_DEV
            if let previewIntent = ForteIntentPreviewLaunch.intent {
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
