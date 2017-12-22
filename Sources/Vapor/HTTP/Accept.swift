import HTTP

public struct Accept {
    public let mediaType: String
    public let preference: Double

    public init(mediaType: String, preference: Double) {
        self.mediaType = mediaType
        self.preference = preference
    }
}

extension Sequence where Iterator.Element == Accept {
    public func prefers(_ mediaType: String) -> Bool {
        guard
            let preference = self
                .first(where: { accept in accept.mediaType.contains(mediaType) })?
                .preference
            else { return false }

        // we need another loop to make sure that another media type isn't _more_ preferred
        for accept in self where accept.preference > preference {
            guard accept.mediaType.contains(mediaType) else { return false }
        }

        return true
    }
}

extension Request {
    public var accept: [Accept] {
        guard let acceptString = headers["accept"] else {
            return []
        }

        let accepts: [Accept] = acceptString.toCharacterSequence().split(separator: ",").flatMap { acceptSlice in
            let pieces = acceptSlice.split(separator: ";")
            guard let mediaType = pieces.first.flatMap({ String($0) }) else { return nil }

            let preference: Double
            if pieces.count == 2 {
                let q = pieces[1].split(separator: "=")
                if q.count == 2 {
                    let preferenceString = String(q[1])
                    preference = Double(preferenceString) ?? 1.0
                } else {
                    preference = 1.0
                }
            } else {
                preference = 1.0
            }

            return Accept(mediaType: mediaType, preference: preference)
        }

        return accepts
    }
}
