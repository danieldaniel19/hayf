import Foundation
import Supabase

enum SupabaseClientProvider {
    static let redirectURL = URL(string: "\(authCallbackScheme)://auth-callback")!
    static let isLocalLangGraphEnabled = environmentValue("HAYF_LOCAL_LANGGRAPH") == "true"

    static let shared = SupabaseClient(
        supabaseURL: supabaseURL,
        supabaseKey: supabaseAnonKey,
        options: SupabaseClientOptions(
            auth: .init(
                redirectToURL: redirectURL,
                emitLocalSessionAsInitialSession: true
            )
        )
    )

    static func environmentValue(_ name: String) -> String? {
        let value = ProcessInfo.processInfo.environment[name]?.trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }

    private static var authCallbackScheme: String {
        guard let configuredScheme = Bundle.main.object(forInfoDictionaryKey: "HAYFAuthCallbackScheme") as? String else {
            return "hayf"
        }

        let trimmedScheme = configuredScheme.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedScheme.isEmpty ? "hayf" : trimmedScheme
    }

    private static var supabaseURL: URL {
        if
            let configuredURL = environmentValue("HAYF_SUPABASE_URL"),
            let url = URL(string: configuredURL)
        {
            return url
        }

        return URL(string: "https://nehwppenlaxozpwqepwp.supabase.co")!
    }

    private static var supabaseAnonKey: String {
        environmentValue("HAYF_SUPABASE_ANON_KEY") ?? "sb_publishable_eN9IUQOtgcGL7dG8jQE26A_KA2FHr-u"
    }
}
