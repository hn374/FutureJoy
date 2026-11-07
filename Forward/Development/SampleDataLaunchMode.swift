enum SampleDataProfile: String, CaseIterable, Identifiable {
    case empty, typical, busy
    case edgeCases = "edge-cases"
    case archiveHeavy = "archive-heavy"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .empty: "Empty"
        case .typical: "Typical"
        case .busy: "Busy"
        case .edgeCases: "Edge cases"
        case .archiveHeavy: "Archive-heavy"
        }
    }

    var storeFilename: String {
        self == .typical ? "Fixtures-v1.store" : "Fixtures-\(rawValue)-v1.store"
    }
}

enum SampleDataLaunchMode: Equatable {
    case disabled
    case enabled(reset: Bool, profile: SampleDataProfile = .typical)
    case invalid(String)

    static func resolve(arguments: [String]) -> SampleDataLaunchMode {
        #if DEBUG && targetEnvironment(simulator)
        guard arguments.contains("--sample-data") else { return .disabled }
        var profile: SampleDataProfile = .typical
        let indices = arguments.indices.filter { arguments[$0] == "--sample-profile" }
        if let index = indices.first {
            guard indices.count == 1, arguments.indices.contains(index + 1),
                  let selected = SampleDataProfile(rawValue: arguments[index + 1]) else {
                return .invalid("Use --sample-profile with empty, typical, busy, edge-cases, or archive-heavy.")
            }
            profile = selected
        }
        return .enabled(reset: arguments.contains("--reset-sample-data"), profile: profile)
        #else
        return .disabled
        #endif
    }
}
