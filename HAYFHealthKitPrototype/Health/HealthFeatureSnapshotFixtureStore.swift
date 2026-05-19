import Foundation

enum HealthFeatureSnapshotFixtureStore {
    static func danielSnapshot() -> HealthFeatureSnapshot? {
        guard let url = Bundle.main.url(forResource: "daniel-health-snapshot", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(HealthFeatureSnapshot.self, from: data)
    }
}
