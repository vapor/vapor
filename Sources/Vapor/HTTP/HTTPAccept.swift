import HTTP

public struct Accept {
    public let mediaType: String
    public let preference: Double

    public init(mediaType: String, preference: Double) {
        self.mediaType = mediaType
        self.preference = preference
    }
}

extension Sequence where Iterator.Element == HTTPAccept {
    public func prefers(_ mediaType: String) -> Bool {
        guard
            let preference = self.lazy
                .filter({ accept in accept.mediaType.contains(mediaType) })
                .first?
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

        var accept: [Accept] = []

        for acceptSlice in acceptString.characters.split(separator: ",") {
            let pieces = acceptSlice.split(separator: ";")
            guard let mediaType = pieces.first.flatMap({ String($0) }) else { continue }


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

            accept.append(HTTPAccept(mediaType: mediaType, preference: preference))
        }

        return accept
    }
}
