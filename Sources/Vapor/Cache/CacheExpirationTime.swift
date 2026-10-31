/// Defines the lifetime of an entry in a cache.
public enum CacheExpirationTime: Sendable {
    case seconds(Int)
    case minutes(Int)
    case hours(Int)
    case days(Int)

    /// Returns the amount of time in seconds.
    public var seconds: Int {
        switch self {
        case .seconds(let seconds):
            return seconds
        case .minutes(let minutes):
            return minutes * 60
        case .hours(let hours):
            return hours * 60 * 60
        case .days(let days):
            return days * 24 * 60 * 60
        }
    }
}
