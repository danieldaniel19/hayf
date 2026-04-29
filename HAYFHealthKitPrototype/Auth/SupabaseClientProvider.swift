import Foundation
import Supabase

enum SupabaseClientProvider {
    static let redirectURL = URL(string: "hayf://auth-callback")!

    static let shared = SupabaseClient(
        supabaseURL: URL(string: "https://nehwppenlaxozpwqepwp.supabase.co")!,
        supabaseKey: "sb_publishable_eN9IUQOtgcGL7dG8jQE26A_KA2FHr-u",
        options: SupabaseClientOptions(
            auth: .init(
                redirectToURL: redirectURL,
                emitLocalSessionAsInitialSession: true
            )
        )
    )
}
