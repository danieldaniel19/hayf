import MapKit
import PhotosUI
import SwiftUI

struct AccountProfile {
    let name: String
    let birthdate: Date
    let mainCity: String
    let profilePhotoData: Data?
    let profilePhotoURL: URL?
}

struct AccountCreationView: View {
    let prefilledName: String?
    let prefilledAvatarURL: URL?
    let existingProfile: StoredAccountProfile?
    let onCreate: (AccountProfile) async throws -> Void
    let onFinish: () -> Void

    @State private var step: AccountCreationStep = .setup
    @State private var name: String
    @State private var birthdate: Date?
    @State private var mainCity = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var attemptedSetupSubmit = false
    @State private var isSaving = false
    @State private var saveErrorMessage: String?
    @StateObject private var citySearchViewModel = CitySearchViewModel()

    private let defaultBirthdate: Date = Calendar.current.date(from: DateComponents(year: 1993, month: 4, day: 15)) ?? .now
    init(
        prefilledName: String? = nil,
        prefilledAvatarURL: URL? = nil,
        existingProfile: StoredAccountProfile? = nil,
        onCreate: @escaping (AccountProfile) async throws -> Void,
        onFinish: @escaping () -> Void
    ) {
        self.prefilledName = existingProfile?.name ?? prefilledName
        self.prefilledAvatarURL = existingProfile?.profilePhotoURL.flatMap(URL.init(string:)) ?? prefilledAvatarURL
        self.existingProfile = existingProfile
        self.onCreate = onCreate
        self.onFinish = onFinish
        _name = State(initialValue: existingProfile?.name ?? prefilledName ?? "")
        _birthdate = State(initialValue: existingProfile.flatMap { Self.storedBirthdateFormatter.date(from: $0.birthdate) })
        _mainCity = State(initialValue: existingProfile?.mainCity ?? "")
    }

    var body: some View {
        ZStack {
            HAYFColor.neutral
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                if step != .success {
                    header
                        .padding(.bottom, 40)
                }

                content
            }
            .padding(.horizontal, 24)
            .padding(.top, 44)
            .padding(.bottom, 20)
            .frame(maxWidth: 480)
        }
        .animation(.easeInOut(duration: 0.22), value: step)
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                selectedPhotoData = try? await newItem?.loadTransferable(type: Data.self)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            HAYFLogo(markSize: 28, textSize: 24, spacing: 8)

            Spacer()

            if step.showsBackButton {
                Button {
                    step = step.previous
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(HAYFColor.primary)
                        .frame(width: 42, height: 42)
                        .background(HAYFColor.neutral)
                        .clipShape(Circle())
                        .overlay {
                            Circle()
                                .stroke(HAYFColor.border, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .setup:
            setupScreen
        case .name:
            nameScreen
        case .birthdate:
            birthdateScreen
        case .city:
            cityScreen
        case .review:
            reviewScreen
        case .success:
            successScreen
        }
    }

    private var setupScreen: some View {
        VStack(alignment: .leading, spacing: 0) {
            AccountIntro(
                eyebrow: "ACCOUNT SETUP",
                title: "Let's set up\nyour account.",
                copy: existingProfile == nil ? "Just a few basics to personalize HAYF. This isn't your workout onboarding." : "Update the basics HAYF uses for your profile."
            )

            ProfilePhotoControl(
                selectedPhotoData: selectedPhotoData,
                avatarURL: prefilledAvatarURL,
                selectedPhotoItem: $selectedPhotoItem,
                size: 96
            )
            .frame(maxWidth: .infinity)
            .padding(.top, 26)

            VStack(spacing: 12) {
                AccountFieldButton(
                    title: "Name",
                    value: name.isEmpty ? "Enter your name" : name,
                    systemImage: "person",
                    isPlaceholder: name.isEmpty,
                    isComplete: !name.trimmed.isEmpty,
                    hasError: attemptedSetupSubmit && name.trimmed.isEmpty
                ) {
                    step = .name
                }

                AccountFieldButton(
                    title: "Birthdate",
                    value: birthdate.map(Self.birthdateFormatter.string(from:)) ?? "Select your birthdate",
                    systemImage: "calendar",
                    isPlaceholder: birthdate == nil,
                    isComplete: birthdate != nil,
                    errorMessage: attemptedSetupSubmit && birthdate == nil ? "Please select your birthdate." : nil
                ) {
                    step = .birthdate
                }

                AccountFieldButton(
                    title: "Main city",
                    value: mainCity.isEmpty ? "Enter your city" : mainCity,
                    systemImage: "mappin.and.ellipse",
                    isPlaceholder: mainCity.isEmpty,
                    isComplete: !mainCity.trimmed.isEmpty,
                    hasError: attemptedSetupSubmit && mainCity.trimmed.isEmpty
                ) {
                    step = .city
                }
            }
            .padding(.top, 22)

            Spacer(minLength: 18)

            AccountPrimaryButton(title: "Continue", isEnabled: true) {
                continueFromSetup()
            }
        }
    }

    private var nameScreen: some View {
        VStack(alignment: .leading, spacing: 0) {
            AccountIntro(
                eyebrow: "ACCOUNT SETUP",
                title: "What should\nHAYF call you?",
                copy: "You can change this later."
            )

            ProfilePhotoControl(
                selectedPhotoData: selectedPhotoData,
                avatarURL: prefilledAvatarURL,
                selectedPhotoItem: $selectedPhotoItem,
                size: 136
            )
            .frame(maxWidth: .infinity)
            .padding(.top, 34)

            VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(HAYFColor.secondary)

                TextField("Enter your name", text: $name)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(HAYFColor.primary)
                    .textInputAutocapitalization(.words)
            }
            .padding(16)
            .frame(height: 76)
            .background(HAYFColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(name.trimmed.isEmpty ? HAYFColor.border : HAYFColor.orange, lineWidth: 1)
            }
            .padding(.top, 34)

            Spacer(minLength: 18)

            AccountPrimaryButton(title: "Continue", isEnabled: !name.trimmed.isEmpty) {
                step = .birthdate
            }
        }
    }

    private var birthdateScreen: some View {
        VStack(alignment: .leading, spacing: 0) {
            AccountIntro(
                eyebrow: "ACCOUNT SETUP",
                title: "When were\nyou born?",
                copy: "HAYF uses this to make age-aware recommendations."
            )

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Birthdate")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(HAYFColor.secondary)

                        Text(birthdate.map(Self.birthdateFormatter.string(from:)) ?? "Select your birthdate")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(birthdate == nil ? HAYFColor.muted : HAYFColor.primary)
                    }

                    Spacer()

                    Image(systemName: "calendar")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(HAYFColor.secondary)
                }
                .padding(16)
                .frame(height: 76)
                .background(HAYFColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(HAYFColor.border, lineWidth: 1)
                }

                DatePicker(
                    "",
                    selection: Binding(
                        get: { birthdate ?? defaultBirthdate },
                        set: { birthdate = $0 }
                    ),
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
            }
            .padding(.top, 34)

            Spacer(minLength: 18)

            AccountPrimaryButton(title: "Continue", isEnabled: true) {
                if birthdate == nil {
                    birthdate = defaultBirthdate
                }
                step = .city
            }
        }
    }

    private var cityScreen: some View {
        VStack(alignment: .leading, spacing: 0) {
            AccountIntro(
                eyebrow: "ACCOUNT SETUP",
                title: "Where are you\nusually based?",
                copy: "This helps HAYF understand weather, travel, and local context later."
            )

            HStack(spacing: 12) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(HAYFColor.secondary)

                TextField("Search for your city", text: $mainCity)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(HAYFColor.primary)
                    .textInputAutocapitalization(.words)
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(HAYFColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(HAYFColor.border, lineWidth: 1)
            }
            .padding(.top, 34)
            .onChange(of: mainCity) { _, newValue in
                citySearchViewModel.updateQuery(newValue)
            }

            Text(citySearchViewModel.sectionTitle(for: mainCity))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(HAYFColor.secondary)
                .padding(.top, 30)

            VStack(spacing: 0) {
                ForEach(citySearchViewModel.suggestions(for: mainCity), id: \.id) { suggestion in
                    Button {
                        mainCity = suggestion.displayName
                        citySearchViewModel.select(suggestion)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundStyle(HAYFColor.secondary)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(suggestion.title)
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundStyle(HAYFColor.primary)

                                if let subtitle = suggestion.subtitle {
                                    Text(subtitle)
                                        .font(.system(size: 13, weight: .regular))
                                        .foregroundStyle(HAYFColor.muted)
                                }
                            }

                            Spacer()
                        }
                        .frame(height: 52)
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .background(HAYFColor.border)
                }
            }
            .padding(.top, 10)

            Spacer(minLength: 18)

            AccountPrimaryButton(title: "Continue", isEnabled: !mainCity.trimmed.isEmpty) {
                step = .review
            }
        }
    }

    private var reviewScreen: some View {
        VStack(alignment: .leading, spacing: 0) {
            AccountIntro(
                eyebrow: "ACCOUNT SETUP",
                title: "Check your\nbasics.",
                copy: "Make sure everything looks right before we create your account."
            )

            VStack(spacing: 10) {
                ReviewRow(
                    systemImage: "person.crop.circle",
                    label: "Photo",
                    value: selectedPhotoData == nil && prefilledAvatarURL == nil ? "Optional" : "Added",
                    action: { step = .name },
                    accessory: {
                        ProfilePhotoPreview(selectedPhotoData: selectedPhotoData, avatarURL: prefilledAvatarURL)
                    }
                )

                ReviewRow(systemImage: "person", label: "Name", value: name.trimmed, action: { step = .name })
                ReviewRow(systemImage: "calendar", label: "Birthdate", value: Self.birthdateFormatter.string(from: birthdate ?? defaultBirthdate), action: { step = .birthdate })
                ReviewRow(systemImage: "mappin.and.ellipse", label: "Main city", value: mainCity.trimmed, action: { step = .city })
            }
            .padding(.top, 32)

            Spacer(minLength: 18)

            if let saveErrorMessage {
                Text(saveErrorMessage)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(HAYFColor.error)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 12)
            }

            AccountPrimaryButton(title: saveButtonTitle, isEnabled: isProfileComplete && !isSaving, isLoading: isSaving) {
                createAccount()
            }
        }
    }

    private var successScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            Circle()
                .stroke(HAYFColor.orange, lineWidth: 1.2)
                .frame(width: 104, height: 104)
                .overlay {
                    Image(systemName: "checkmark")
                        .font(.system(size: 40, weight: .regular))
                        .foregroundStyle(HAYFColor.orange)
                }

            Text("Account\ncreated.")
                .font(.system(size: 34, weight: .bold, design: .default))
                .lineSpacing(1)
                .multilineTextAlignment(.center)
                .foregroundStyle(HAYFColor.primary)
                .padding(.top, 34)

            Text("Next, HAYF will learn what kind of training fits your life.")
                .font(.system(size: 16, weight: .regular))
                .lineSpacing(4)
                .multilineTextAlignment(.center)
                .foregroundStyle(HAYFColor.secondary)
                .frame(maxWidth: 248)
                .padding(.top, 18)

            Spacer()

            AccountPrimaryButton(title: existingProfile == nil ? "Start onboarding" : "Back to HAYF", isEnabled: true) {
                onFinish()
            }
        }
    }

    private var isProfileComplete: Bool {
        !name.trimmed.isEmpty && birthdate != nil && !mainCity.trimmed.isEmpty
    }

    private var saveButtonTitle: String {
        if isSaving {
            return existingProfile == nil ? "Creating account" : "Updating account"
        }

        return existingProfile == nil ? "Create account" : "Update account"
    }

    private func continueFromSetup() {
        attemptedSetupSubmit = true

        if name.trimmed.isEmpty {
            step = .name
        } else if birthdate == nil {
            step = .birthdate
        } else if mainCity.trimmed.isEmpty {
            step = .city
        } else {
            step = .review
        }
    }

    private func createAccount() {
        guard let birthdate, isProfileComplete else {
            attemptedSetupSubmit = true
            step = .setup
            return
        }

        let profile = AccountProfile(
            name: name.trimmed,
            birthdate: birthdate,
            mainCity: mainCity.trimmed,
            profilePhotoData: selectedPhotoData,
            profilePhotoURL: prefilledAvatarURL
        )

        Task {
            isSaving = true
            saveErrorMessage = nil
            defer { isSaving = false }

            do {
                try await onCreate(profile)
                step = .success
            } catch {
                saveErrorMessage = error.localizedDescription
            }
        }
    }

    private static let birthdateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()

    private static let storedBirthdateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private enum AccountCreationStep {
    case setup
    case name
    case birthdate
    case city
    case review
    case success

    var showsBackButton: Bool {
        self != .setup && self != .success
    }

    var previous: AccountCreationStep {
        switch self {
        case .setup, .success:
            return .setup
        case .name:
            return .setup
        case .birthdate:
            return .name
        case .city:
            return .birthdate
        case .review:
            return .city
        }
    }
}

private struct CitySuggestion: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String?

    var displayName: String {
        [title, subtitle]
            .compactMap { $0?.trimmed }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}

private final class CitySearchViewModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published private var completions: [MKLocalSearchCompletion] = []
    @Published private var selectedDisplayName: String?

    private let completer = MKLocalSearchCompleter()
    private let popularSuggestions = [
        CitySuggestion(id: "popular-berlin", title: "Berlin", subtitle: "Germany"),
        CitySuggestion(id: "popular-lisbon", title: "Lisbon", subtitle: "Portugal"),
        CitySuggestion(id: "popular-new-york", title: "New York", subtitle: "United States"),
        CitySuggestion(id: "popular-london", title: "London", subtitle: "United Kingdom"),
        CitySuggestion(id: "popular-sydney", title: "Sydney", subtitle: "Australia")
    ]

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }

    func updateQuery(_ query: String) {
        let trimmedQuery = query.trimmed

        if trimmedQuery == selectedDisplayName {
            completer.queryFragment = ""
            completions = []
            return
        }

        selectedDisplayName = nil
        completer.queryFragment = trimmedQuery.count >= 2 ? trimmedQuery : ""

        if trimmedQuery.count < 2 {
            completions = []
        }
    }

    func select(_ suggestion: CitySuggestion) {
        selectedDisplayName = suggestion.displayName
        completer.queryFragment = ""
        completions = []
    }

    func sectionTitle(for query: String) -> String {
        guard query.trimmed.count >= 2, selectedDisplayName != query.trimmed else {
            return "Popular suggestions"
        }

        return completions.isEmpty ? "Popular suggestions" : "Suggestions"
    }

    func suggestions(for query: String) -> [CitySuggestion] {
        guard query.trimmed.count >= 2, selectedDisplayName != query.trimmed else {
            return popularSuggestions
        }

        let suggestions = completions.map { completion in
            CitySuggestion(
                id: "\(completion.title)-\(completion.subtitle)",
                title: completion.title,
                subtitle: completion.subtitle.trimmed.isEmpty ? nil : completion.subtitle
            )
        }

        return suggestions.isEmpty ? popularSuggestions : suggestions
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.completions = completer.results
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.completions = []
        }
    }
}

private struct AccountIntro: View {
    let eyebrow: String
    let title: String
    let copy: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(eyebrow)
                .font(.system(size: 12, weight: .medium))
                .kerning(1.2)
                .foregroundStyle(HAYFColor.secondary)

            Text(title)
                .font(.system(size: 32, weight: .bold, design: .default))
                .lineSpacing(2)
                .foregroundStyle(HAYFColor.primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 22)

            Text(copy)
                .font(.system(size: 16, weight: .regular))
                .lineSpacing(4)
                .foregroundStyle(HAYFColor.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 16)
        }
    }
}

private struct ProfilePhotoControl: View {
    let selectedPhotoData: Data?
    let avatarURL: URL?
    @Binding var selectedPhotoItem: PhotosPickerItem?
    let size: CGFloat

    private var hasPhoto: Bool {
        selectedPhotoData != nil || avatarURL != nil
    }

    var body: some View {
        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
            ProfilePhotoPreview(selectedPhotoData: selectedPhotoData, avatarURL: avatarURL)
                .frame(width: size, height: size)
                .overlay(alignment: .topTrailing) {
                    if hasPhoto {
                        Circle()
                            .fill(HAYFColor.surface)
                            .frame(width: size * 0.26, height: size * 0.26)
                            .overlay {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: size * 0.2, weight: .semibold))
                                    .foregroundStyle(HAYFColor.orange)
                            }
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    Circle()
                        .fill(HAYFColor.orange)
                        .frame(width: size * 0.32, height: size * 0.32)
                        .overlay {
                            Image(systemName: selectedPhotoData == nil && avatarURL == nil ? "camera.fill" : "pencil")
                                .font(.system(size: size * 0.13, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Choose profile photo")
    }
}

private struct ProfilePhotoPreview: View {
    let selectedPhotoData: Data?
    let avatarURL: URL?

    var body: some View {
        Group {
            if let selectedPhotoData, let image = UIImage(data: selectedPhotoData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let avatarURL {
                AsyncImage(url: avatarURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .clipShape(Circle())
        .background {
            Circle()
                .fill(Color(red: 232 / 255, green: 232 / 255, blue: 228 / 255))
        }
    }

    private var placeholder: some View {
        Circle()
            .fill(Color(red: 232 / 255, green: 232 / 255, blue: 228 / 255))
            .overlay {
                Image(systemName: "person.fill")
                    .font(.system(size: 34, weight: .regular))
                    .foregroundStyle(HAYFColor.secondary)
            }
    }
}

private struct AccountFieldButton: View {
    let title: String
    let value: String
    let systemImage: String
    var isPlaceholder = false
    var isComplete = false
    var errorMessage: String?
    var hasError = false
    let action: () -> Void

    private var showsError: Bool {
        errorMessage != nil || hasError
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: action) {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(showsError ? HAYFColor.error : HAYFColor.secondary)

                        Text(value)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(isPlaceholder ? HAYFColor.muted : HAYFColor.primary)
                    }

                    Spacer()

                    if isComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(HAYFColor.orange)
                            .accessibilityLabel("\(title) complete")
                    } else {
                        Image(systemName: systemImage)
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(HAYFColor.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .frame(height: 70)
                .background(HAYFColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(showsError ? HAYFColor.error : HAYFColor.border, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(HAYFColor.error)
                    .padding(.leading, 2)
            }
        }
    }
}

private struct AccountPrimaryButton: View {
    let title: String
    let isEnabled: Bool
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                } else {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(isEnabled ? .white : HAYFColor.muted)
                        .frame(maxWidth: .infinity)
                }

                Image(systemName: "arrow.right")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(isEnabled ? .white : HAYFColor.muted)
            }
            .padding(.horizontal, 20)
            .frame(height: 56)
            .background(isEnabled ? HAYFColor.primary : Color(red: 196 / 255, green: 196 / 255, blue: 192 / 255))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

private struct ReviewRow<Accessory: View>: View {
    let systemImage: String
    let label: String
    let value: String
    let action: () -> Void
    @ViewBuilder let accessory: () -> Accessory

    init(
        systemImage: String,
        label: String,
        value: String,
        action: @escaping () -> Void,
        @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() }
    ) {
        self.systemImage = systemImage
        self.label = label
        self.value = value
        self.action = action
        self.accessory = accessory
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(HAYFColor.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(HAYFColor.secondary)

                Text(value)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(HAYFColor.primary)
                    .lineLimit(1)
            }

            Spacer()

            accessory()
                .frame(width: 44, height: 44)

            Button(action: action) {
                Image(systemName: "pencil")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(HAYFColor.secondary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit \(label)")
        }
        .padding(.horizontal, 16)
        .frame(height: 74)
        .background(HAYFColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(HAYFColor.border, lineWidth: 1)
        }
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    AccountCreationView(
        prefilledName: "Daniel",
        prefilledAvatarURL: nil,
        onCreate: { _ in },
        onFinish: {}
    )
}
