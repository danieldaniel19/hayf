import Foundation
import Supabase

@MainActor
final class PlanDataStore: ObservableObject {
    @Published private(set) var activeBlock: PlanActiveFitnessBlock?
    @Published private(set) var phases: [PlanFitnessBlockPhase] = []
    @Published private(set) var weeklyRhythms: [PlanWeeklyRhythm] = []
    @Published private(set) var workouts: [PlanWorkout] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let supabase: SupabaseClient
    private let calendar: Calendar

    init(
        supabase: SupabaseClient = SupabaseClientProvider.shared,
        calendar: Calendar = PlanCalendar.iso
    ) {
        self.supabase = supabase
        self.calendar = calendar
    }

    func loadVisiblePlan() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            guard let block = try await fetchActiveBlock() else {
                activeBlock = nil
                phases = []
                weeklyRhythms = []
                workouts = []
                return
            }

            async let phases = fetchPhases(for: block.id)
            async let weeklyRhythms = fetchWeeklyRhythms(for: block.id)
            async let workouts = fetchWorkouts(for: block.id)

            activeBlock = block
            self.phases = try await phases
            self.weeklyRhythms = try await weeklyRhythms
            self.workouts = try await workouts
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func fetchActiveBlock() async throws -> PlanActiveFitnessBlock? {
        do {
            let block: PlanActiveFitnessBlock = try await supabase
                .from("active_fitness_blocks")
                .select("id, kind, title, goal_text, status, start_date, target_date, review_cadence_days, timezone, context_json")
                .eq("status", value: "active")
                .single()
                .execute()
                .value

            return block
        } catch let error as PostgrestError where error.code == "PGRST116" {
            return nil
        }
    }

    private func fetchPhases(for blockID: UUID) async throws -> [PlanFitnessBlockPhase] {
        try await supabase
            .from("fitness_block_phases")
            .select("id, active_block_id, name, start_date, end_date, objective, focus_json, risk_json")
            .eq("active_block_id", value: blockID.uuidString.lowercased())
            .order("start_date", ascending: true)
            .execute()
            .value
    }

    private func fetchWeeklyRhythms(for blockID: UUID) async throws -> [PlanWeeklyRhythm] {
        let window = visibleWindow()

        return try await supabase
            .from("weekly_rhythms")
            .select("id, active_block_id, week_start_date, week_end_date, objective, bad_day_floor, status")
            .eq("active_block_id", value: blockID.uuidString.lowercased())
            .eq("status", value: "active")
            .gte("week_start_date", value: PlanCalendar.dateFormatter.string(from: window.start))
            .lte("week_start_date", value: PlanCalendar.dateFormatter.string(from: window.end))
            .order("week_start_date", ascending: true)
            .execute()
            .value
    }

    private func fetchWorkouts(for blockID: UUID) async throws -> [PlanWorkout] {
        let window = visibleWindow()

        return try await supabase
            .from("planned_workouts")
            .select("id, active_block_id, weekly_rhythm_id, scheduled_date, sequence_order, activity_type, title, duration_minutes, intensity_label, purpose, status, source, fueling_summary")
            .eq("active_block_id", value: blockID.uuidString.lowercased())
            .gte("scheduled_date", value: PlanCalendar.dateFormatter.string(from: window.start))
            .lte("scheduled_date", value: PlanCalendar.dateFormatter.string(from: window.end))
            .not("status", operator: .in, value: "(deleted,superseded)")
            .order("scheduled_date", ascending: true)
            .order("sequence_order", ascending: true)
            .execute()
            .value
    }

    private func visibleWindow() -> DateInterval {
        let now = Date()
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let nextWeekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart) ?? now
        let nextWeekEnd = calendar.date(byAdding: .day, value: 6, to: nextWeekStart) ?? nextWeekStart
        return DateInterval(start: currentWeekStart, end: nextWeekEnd)
    }
}

enum PlanCalendar {
    static var iso: Calendar = {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        return calendar
    }()

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

struct PlanActiveFitnessBlock: Decodable, Identifiable {
    let id: UUID
    let kind: String
    let title: String
    let goalText: String?
    let status: String
    let startDate: String
    let targetDate: String?
    let reviewCadenceDays: Int
    let timezone: String
    let context: PlanBlockContext

    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case title
        case goalText = "goal_text"
        case status
        case startDate = "start_date"
        case targetDate = "target_date"
        case reviewCadenceDays = "review_cadence_days"
        case timezone
        case context = "context_json"
    }
}

struct PlanBlockContext: Decodable {
    let onboardingIntent: String?
    let planningRationale: String?
    let dataFreshness: String?
    let timezone: String?
}

struct PlanFitnessBlockPhase: Decodable, Identifiable {
    let id: UUID
    let activeBlockID: UUID
    let name: String
    let startDate: String?
    let endDate: String?
    let objective: String
    let focus: [String]
    let risk: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case activeBlockID = "active_block_id"
        case name
        case startDate = "start_date"
        case endDate = "end_date"
        case objective
        case focus = "focus_json"
        case risk = "risk_json"
    }
}

struct PlanWeeklyRhythm: Decodable, Identifiable {
    let id: UUID
    let activeBlockID: UUID
    let weekStartDate: String
    let weekEndDate: String
    let objective: String
    let badDayFloor: String?
    let status: String

    enum CodingKeys: String, CodingKey {
        case id
        case activeBlockID = "active_block_id"
        case weekStartDate = "week_start_date"
        case weekEndDate = "week_end_date"
        case objective
        case badDayFloor = "bad_day_floor"
        case status
    }
}

struct PlanWorkout: Decodable, Identifiable {
    let id: UUID
    let activeBlockID: UUID
    let weeklyRhythmID: UUID?
    let scheduledDate: String
    let sequenceOrder: Int
    let activityType: String
    let title: String
    let durationMinutes: Int
    let intensityLabel: String
    let purpose: String
    let status: PlanWorkoutStatus
    let source: String
    let fuelingSummary: String?

    enum CodingKeys: String, CodingKey {
        case id
        case activeBlockID = "active_block_id"
        case weeklyRhythmID = "weekly_rhythm_id"
        case scheduledDate = "scheduled_date"
        case sequenceOrder = "sequence_order"
        case activityType = "activity_type"
        case title
        case durationMinutes = "duration_minutes"
        case intensityLabel = "intensity_label"
        case purpose
        case status
        case source
        case fuelingSummary = "fueling_summary"
    }
}

enum PlanWorkoutStatus: String, Decodable {
    case planned
    case current
    case checkedIn = "checked_in"
    case adjusted
    case done
    case missed
    case deleted
    case superseded

    var displayName: String {
        switch self {
        case .planned:
            return "Open"
        case .current:
            return "Current"
        case .checkedIn:
            return "Checked in"
        case .adjusted:
            return "Adjusted"
        case .done:
            return "Done"
        case .missed:
            return "Missed"
        case .deleted:
            return "Deleted"
        case .superseded:
            return "Superseded"
        }
    }
}
