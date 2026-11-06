enum SampleDataLaunchMode: Equatable {
    case disabled
    case enabled(reset: Bool)

    static func resolve(arguments: [String]) -> SampleDataLaunchMode {
        #if DEBUG && targetEnvironment(simulator)
        guard arguments.contains("--sample-data") else { return .disabled }
        return .enabled(reset: arguments.contains("--reset-sample-data"))
        #else
        return .disabled
        #endif
    }
}
