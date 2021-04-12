/// Defines the lifetime of an entry in a cache.
public enum CacheExpirationTime {
    case seconds(Int)
    case minutes(Int)
    case hours(Int)
    case days(Int)
    
    /// Returns the amount of time in seconds.
    public var seconds: Int {
        switch self {
        case let .seconds(seconds):
            return seconds
        case let .minutes(minutes):
            return minutes * 60
        case let .hours(hours):
            return hours * 60 * 60
        case let .days(days):
            return days * 24 * 60 * 60
        }
    }
}
