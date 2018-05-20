import HTTP

public struct AcceptLanguage {
    public let languageRange: String
    public let quality: Double
}

extension Request {
    public var acceptLanguage: [AcceptLanguage] {
        guard let acceptLanguageString = headers["Accept-Language"] else {
            return []
        }
        
        #if swift(>=4.1)
        return acceptLanguageString.toCharacterSequence().split(separator: ",").compactMap { acceptLanguageSlice in
            let pieces = acceptLanguageSlice.split(separator: ";")
            guard let languageRange = pieces.first.flatMap({ String($0).trimmingCharacters(in: .whitespaces) }) else { return nil }
            
            let quality: Double
            if pieces.count == 2 {
                let q = pieces[1].split(separator: "=")
                if q.count == 2 {
                    let valueString = String(q[1])
                    quality = Double(valueString) ?? 1.0
                } else {
                    quality = 1.0
                }
            } else {
                quality = 1.0
            }
            
            return AcceptLanguage(languageRange: languageRange, quality: quality)
        }
        #else
        return acceptLanguageString.toCharacterSequence().split(separator: ",").flatMap { acceptLanguageSlice in
            let pieces = acceptLanguageSlice.split(separator: ";")
            guard let languageRange = pieces.first.flatMap({ String($0).trimmingCharacters(in: .whitespaces) }) else { return nil }
            
            let quality: Double
            if pieces.count == 2 {
                let q = pieces[1].split(separator: "=")
                if q.count == 2 {
                    let valueString = String(q[1])
                    quality = Double(valueString) ?? 1.0
                } else {
                    quality = 1.0
                }
            } else {
                quality = 1.0
            }
            
            return AcceptLanguage(languageRange: languageRange, quality: quality)
        }
        #endif
    }
}

extension Request {
    public var lang: String {
        return headers["Accept-Language"]?.string ?? ""
    }
}
