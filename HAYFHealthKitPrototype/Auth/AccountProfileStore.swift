import Foundation
import Supabase

struct StoredAccountProfile: Codable, Identifiable {
    let id: UUID
    let name: String
    let birthdate: String
    let mainCity: String
    let profilePhotoPath: String?
    let profilePhotoURL: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case birthdate
        case mainCity = "main_city"
        case profilePhotoPath = "profile_photo_path"
        case profilePhotoURL = "profile_photo_url"
    }
}

private struct CreateAccountProfileRequest: Encodable {
    let id: UUID
    let name: String
    let birthdate: String
    let mainCity: String
    let profilePhotoPath: String?
    let profilePhotoURL: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case birthdate
        case mainCity = "main_city"
        case profilePhotoPath = "profile_photo_path"
        case profilePhotoURL = "profile_photo_url"
    }
}

@MainActor
final class AccountProfileStore: ObservableObject {
    @Published private(set) var profile: StoredAccountProfile?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let supabase = SupabaseClientProvider.shared
    private let birthdateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    func loadCurrentUserProfile() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            profile = try await fetchCurrentUserProfile()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createCurrentUserProfile(from draft: AccountProfile) async throws -> StoredAccountProfile {
        let user = try await supabase.auth.session.user
        let profilePhotoPath = try await uploadProfilePhotoIfNeeded(draft.profilePhotoData, userID: user.id)
        let profilePhotoURL = profilePhotoPath == nil ? draft.profilePhotoURL?.absoluteString : nil

        let request = CreateAccountProfileRequest(
            id: user.id,
            name: draft.name,
            birthdate: birthdateFormatter.string(from: draft.birthdate),
            mainCity: draft.mainCity,
            profilePhotoPath: profilePhotoPath,
            profilePhotoURL: profilePhotoURL
        )

        let createdProfile: StoredAccountProfile = try await supabase
            .from("profiles")
            .insert(request)
            .select()
            .single()
            .execute()
            .value

        return createdProfile
    }

    func useProfile(_ profile: StoredAccountProfile) {
        self.profile = profile
        errorMessage = nil
    }

    func reset() {
        profile = nil
        errorMessage = nil
        isLoading = false
    }

    private func fetchCurrentUserProfile() async throws -> StoredAccountProfile? {
        let user = try await supabase.auth.session.user

        do {
            let profile: StoredAccountProfile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: user.id)
                .single()
                .execute()
                .value

            return profile
        } catch let error as PostgrestError where error.code == "PGRST116" {
            return nil
        }
    }

    private func uploadProfilePhotoIfNeeded(_ photoData: Data?, userID: UUID) async throws -> String? {
        guard let photoData else {
            return nil
        }

        let filePath = "\(userID.uuidString.lowercased())/avatar.jpg"

        try await supabase.storage
            .from("profile-photos")
            .upload(
                filePath,
                data: photoData,
                options: FileOptions(contentType: "image/jpeg", upsert: true)
            )

        return filePath
    }
}
