import Foundation
import NIOHTTP1

/// Represents a `MediaType` and its associated preference, `q`.
public struct HTTPMediaTypePreference {
    /// The `MediaType` in question.
    public var mediaType: HTTPMediaType

    /// Its associated preference.
    public var q: Double?

    init?(directives: [HTTPHeaders.Directive]) {
        guard let mediaType = HTTPMediaType(directives: directives) else {
            return nil
        }
        self.mediaType = mediaType
        self.q = directives.first(where: { $0.value == "q" }).flatMap {
            $0.parameter.flatMap(Double.init)
        }
    }
}

extension Array where Element == HTTPMediaTypePreference {
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
                return .orderedDescending
            } else {
                return .orderedAscending
            }
        case (.none, .some):
            // there is not a value for a, no way it can be preferred
            return .orderedAscending
        case (.some, .none):
            // there is not a value for b, a is preferred by default
            return .orderedDescending
        case (.none, .none):
            // there is no value for either, neither is preferred
            return .orderedSame
        }
    }
}
