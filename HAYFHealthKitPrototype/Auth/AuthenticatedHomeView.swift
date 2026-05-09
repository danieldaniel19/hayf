import SwiftUI

struct AuthenticatedHomeView: View {
    let userEmail: String?
    let displayName: String?
    let presentActiveBlockOnFirstPlanLoad: Bool
    let onDidPresentActiveBlockOnFirstPlanLoad: () -> Void
    let restartAccountCreation: () -> Void
    let restartOnboarding: () -> Void
    let signOut: () -> Void

    @State private var selectedTab: AuthenticatedTab = .plan
    @State private var isShowingHealthDebug = false
    @State private var didRunPlanningRefresh = false

    private let healthSyncService = HealthSyncService()
    private let planningAIProvider = PlanningAIProvider()

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayGhostView()
                .tabItem {
                    Label("Today", systemImage: "house")
                }
                .tag(AuthenticatedTab.today)

            PlanScreenView(
                presentActiveBlockOnFirstLoad: presentActiveBlockOnFirstPlanLoad,
                onDidPresentActiveBlockOnFirstLoad: onDidPresentActiveBlockOnFirstPlanLoad
            )
                .tabItem {
                    Label("Plan", systemImage: "calendar")
                }
                .tag(AuthenticatedTab.plan)

            ProfileView(
                userEmail: userEmail,
                displayName: displayName,
                signOut: signOut
            )
            .tabItem {
                Label("Profile", systemImage: "person")
            }
            .tag(AuthenticatedTab.profile)

            DevToolsView(
                restartAccountCreation: restartAccountCreation,
                restartOnboarding: restartOnboarding,
                showHealthDebug: { isShowingHealthDebug = true }
            )
            .tabItem {
                Label("Dev", systemImage: "wrench.and.screwdriver")
            }
            .tag(AuthenticatedTab.dev)
        }
        .tint(HAYFColor.orange)
        .sheet(isPresented: $isShowingHealthDebug) {
            HealthDebugView()
        }
        .task {
            await refreshPlanningOnOpen()
        }
    }

    private func refreshPlanningOnOpen() async {
        guard !didRunPlanningRefresh else { return }
        didRunPlanningRefresh = true

        if let payload = try? await healthSyncService.buildSyncPayload(daysBack: 14) {
            _ = try? await planningAIProvider.syncHealthKitAndReconcile(payload: payload)
        }

        _ = try? await planningAIProvider.refreshPlanWindow()
    }
}

private enum AuthenticatedTab: Hashable {
    case today
    case plan
    case profile
    case dev
}

private struct TodayGhostView: View {
    var body: some View {
        HAYFGhostScreen(
            title: "Today",
            message: "The daily recommendation card will live here soon.",
            systemImage: "house"
        )
    }
}

private struct ProfileView: View {
    let userEmail: String?
    let displayName: String?
    let signOut: () -> Void

    var body: some View {
        ZStack {
            HAYFColor.neutral
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 28) {
                HAYFLogo(markSize: 34, textSize: 30, spacing: 10)

                VStack(alignment: .leading, spacing: 12) {
                    Text(displayName ?? "Profile")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(HAYFColor.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    if let userEmail {
                        Text(userEmail)
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(HAYFColor.muted)
                    }
                }

                Spacer()

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
            }
            .padding(.horizontal, 30)
            .padding(.top, 28)
            .padding(.bottom, 28)
            .frame(maxWidth: 520)
        }
    }
}

private struct DevToolsView: View {
    let restartAccountCreation: () -> Void
    let restartOnboarding: () -> Void
    let showHealthDebug: () -> Void

    var body: some View {
        ZStack {
            HAYFColor.neutral
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 28) {
                HAYFLogo(markSize: 34, textSize: 30, spacing: 10)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Dev")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(HAYFColor.primary)

                    Text("Useful QA entry points live here now.")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(HAYFColor.muted)
                }

                VStack(spacing: 12) {
                    DevEntryButton(title: "Health debug", systemImage: "heart.text.square", action: showHealthDebug)
                    DevEntryButton(title: "Restart account creation", systemImage: "person.crop.circle.badge.plus", action: restartAccountCreation)
                    DevEntryButton(title: "Restart onboarding", systemImage: "arrow.triangle.2.circlepath", action: restartOnboarding)
                }

                Spacer()
            }
            .padding(.horizontal, 30)
            .padding(.top, 28)
            .frame(maxWidth: 520)
        }
    }
}

private struct HAYFGhostScreen: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        ZStack {
            HAYFColor.neutral
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 28) {
                HAYFLogo(markSize: 34, textSize: 30, spacing: 10)

                Spacer()

                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: systemImage)
                        .font(.system(size: 28, weight: .regular))
                        .foregroundStyle(HAYFColor.orange)
                        .frame(width: 54, height: 54)
                        .background(HAYFColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(HAYFColor.borderStrong, lineWidth: 1)
                        }

                    Text(title)
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(HAYFColor.primary)

                    Text(message)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(HAYFColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .padding(.horizontal, 30)
            .padding(.top, 28)
            .padding(.bottom, 28)
            .frame(maxWidth: 520)
        }
    }
}

private struct DevEntryButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(HAYFColor.orange)
                    .frame(width: 24)

                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(HAYFColor.primary)

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(HAYFColor.muted)
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
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

#Preview {
    AuthenticatedHomeView(
        userEmail: "you@example.com",
        displayName: "Daniel",
        presentActiveBlockOnFirstPlanLoad: false,
        onDidPresentActiveBlockOnFirstPlanLoad: {},
        restartAccountCreation: {},
        restartOnboarding: {},
        signOut: {}
    )
}
