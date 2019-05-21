/// Represents a `MediaType` and its associated preference, `q`.
public struct HTTPMediaTypePreference {
    /// The `MediaType` in question.
    public var mediaType: HTTPMediaType
    
    /// Its associated preference.
    public var q: Double?
}

extension Array where Element == HTTPMediaTypePreference {
    /// Parses an array of `[MediaTypePreference]` from an accept header value
    ///
    /// - parameters:
    ///     - data: The accept header value to parse.
    public static func parse(_ data: String) -> [HTTPMediaTypePreference] {
        return data.split(separator: ",").compactMap { token in
            let parts = token.split(separator: ";", maxSplits: 1)
            let value = String(parts[0]).trimmingCharacters(in: .whitespaces)
            guard let mediaType = HTTPMediaType.parse(value) else {
                return nil
            }
            switch parts.count {
            case 1: return .init(mediaType: mediaType, q: nil)
            case 2:
                let qparts = parts[1].split(separator: "=", maxSplits: 1)
                guard qparts.count == 2 else {
                    return nil
                }
                guard let preference = Double(qparts[1]) else {
                    return nil
                }
                return .init(mediaType: mediaType, q: preference)
            default: return nil
            }
        }
    }
    
    /// Returns all `MediaType`s in this array of `MediaTypePreference`.
    ///
    ///     httpReq.accept.mediaTypes.contains(.html)
    ///
    public var mediaTypes: [HTTPMediaType] {
        return map { $0.mediaType }
    }
    
    /// Returns `ComparisonResult` comparing the supplied `MediaType`s against these preferences.
    ///
    ///     let pref = httpReq.accept.comparePreference(for: .json, to: .html)
    ///
    public func comparePreference(for a: HTTPMediaType, to b: HTTPMediaType) -> ComparisonResult {
        let aq = self.filter { $0.mediaType == a }
            .map { $0.q ?? 1.0 }
            .first
        let bq = self.filter { $0.mediaType == b }
            .map { $0.q ?? 1.0 }
            .first
        switch (aq, bq) {
        case (.some(let aq), .some(let bq)):
            // there is a value for both media types, compare the preference
            if aq == bq {
                return .orderedSame
            } else if aq > bq {
                return .orderedAscending
            } else {
                return .orderedDescending
            }
        case (.none, .some):
            // there is not a value for a, no way it can be preferred
            return .orderedDescending
        case (.some, .none):
            // there is not a value for b, a is preferred by default
            return .orderedAscending
        case (.none, .none):
            // there is no value for either, neither is preferred
            return .orderedSame
        }
    }
}
