enum AuthMode {
    case signIn
    case signUp

    var alternate: AuthMode {
        switch self {
        case .signIn:
            return .signUp
        case .signUp:
            return .signIn
        }
    }

    var eyebrow: String {
        switch self {
        case .signIn:
            return "WELCOME BACK"
        case .signUp:
            return "START WITH HAYF"
        }
    }

    var headline: String {
        switch self {
        case .signIn:
            return "You've got\nthis."
        case .signUp:
            return "Train for the\nlife you have."
        }
    }

    var bodyCopy: String {
        switch self {
        case .signIn:
            return "Smart, adaptive training guidance\nthat moves with you."
        case .signUp:
            return "Build a realistic rhythm around your schedule, recovery, and goals."
        }
    }

    var googleTitle: String {
        switch self {
        case .signIn:
            return "Continue with Google"
        case .signUp:
            return "Start with Google"
        }
    }

    var appleTitle: String {
        switch self {
        case .signIn:
            return "Continue with Apple"
        case .signUp:
            return "Start with Apple"
        }
    }

    var emailTitle: String {
        switch self {
        case .signIn:
            return "Continue with Email"
        case .signUp:
            return "Start with Email"
        }
    }

    var switchPrompt: String {
        switch self {
        case .signIn:
            return "New to HAYF?"
        case .signUp:
            return "Already have an account?"
        }
    }

    var switchAction: String {
        switch self {
        case .signIn:
            return "Create account"
        case .signUp:
            return "Sign in"
        }
    }
}
