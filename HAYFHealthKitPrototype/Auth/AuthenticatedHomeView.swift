import SwiftUI

struct AuthenticatedHomeView: View {
    let userEmail: String?
    let accountProfile: StoredAccountProfile
    let presentActiveBlockOnFirstPlanLoad: Bool
    let onDidPresentActiveBlockOnFirstPlanLoad: () -> Void
    let restartAccountCreation: () -> Void
    let restartOnboarding: () -> Void
    let signOut: () -> Void

    @State private var selectedTab: AuthenticatedTab = .today
    @State private var isShowingHealthDebug = false

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayScreenView(userName: accountProfile.name)
                .tabItem {
                    Label("Today", systemImage: "house")
                }
                .tag(AuthenticatedTab.today)

            PlanScreenView(
                userName: accountProfile.name,
                presentActiveBlockOnFirstLoad: presentActiveBlockOnFirstPlanLoad,
                onDidPresentActiveBlockOnFirstLoad: onDidPresentActiveBlockOnFirstPlanLoad
            )
                .tabItem {
                    Label("Plan", systemImage: "calendar")
                }
                .tag(AuthenticatedTab.plan)

            ProfileScreenView(
                accountProfile: accountProfile,
                userEmail: userEmail,
                editProfile: restartAccountCreation,
                reviewGoal: restartOnboarding,
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
    }
}

private enum AuthenticatedTab: Hashable {
    case today
    case plan
    case profile
    case dev
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
        accountProfile: StoredAccountProfile(
            id: UUID(),
            name: "Daniel",
            birthdate: "1990-01-01",
            physiologyReference: "male",
            mainCity: "Lisbon",
            profilePhotoPath: nil,
            profilePhotoURL: nil
        ),
        presentActiveBlockOnFirstPlanLoad: false,
        onDidPresentActiveBlockOnFirstPlanLoad: {},
        restartAccountCreation: {},
        restartOnboarding: {},
        signOut: {}
    )
}
