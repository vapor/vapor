public struct HTTPAccept {
    var mediaType: String
    var preference: Double
}

extension Sequence where Iterator.Element == HTTPAccept {
    public func prefers(_ mediaType: String) -> Bool {
        var foundPreference: Double? = nil

        for accept in self {
            if accept.mediaType.contains(mediaType) {
                foundPreference = accept.preference
            }
        }

        guard let preference = foundPreference else {
            return false
        }

        for accept in self {
            if accept.preference > preference && !accept.mediaType.contains(mediaType) {
                return false
            }
        }

        return true
    }
}

extension HTTPRequest {
    public var accept: [HTTPAccept] {
        guard let acceptString = headers["accept"] else {
            return []
        }

        var accept: [HTTPAccept] = []

        for acceptSlice in acceptString.characters.split(separator: ",") {
            let pieces = acceptSlice.split(separator: ";")

            let mediaType = String(pieces[0])

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
