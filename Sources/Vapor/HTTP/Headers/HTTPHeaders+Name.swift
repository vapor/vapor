import HTTPTypes

extension HTTPField.Name {

    // https://www.iana.org/assignments/message-headers/message-headers.xhtml
    // Permanent Message Header Field Names

    /// A-IM header.
    public static let aIM = Self("A-IM")
    /// Accept-Additions header.
    public static let acceptAdditions = Self("Accept-Additions")
    /// Accept-Charset header.
    public static let acceptCharset = Self("Accept-Charset")
    /// Accept-Datetime header.
    public static let acceptDatetime = Self("Accept-Datetime")
    /// Accept-Features header.
    public static let acceptFeatures = Self("Accept-Features")
    /// Accept-Patch header.
    public static let acceptPatch = Self("Accept-Patch")
    /// Accept-Post header.
    public static let acceptPost = Self("Accept-Post")
    /// ALPN header.
    public static let alpn = Self("ALPN")
    /// Alt-Svc header.
    public static let altSvc = Self("Alt-Svc")
    /// Alt-Used header.
    public static let altUsed = Self("Alt-Used")
    /// Alternates header.
    public static let alternates = Self("Alternates")
    /// Apply-To-Redirect-Ref header.
    public static let applyToRedirectRef = Self("Apply-To-Redirect-Ref")
    /// Authentication-Control header.
    public static let authenticationControl = Self("Authentication-Control")
    /// C-Ext header.
    public static let cExt = Self("C-Ext")
    /// C-Man header.
    public static let cMan = Self("C-Man")
    /// C-Opt header.
    public static let cOpt = Self("C-Opt")
    /// C-PEP header.
    public static let cPEP = Self("C-PEP")
    /// C-PEP-Info header.
    public static let cPEPInfo = Self("C-PEP-Info")
    /// CalDav-Timezones header.
    public static let calDAVTimezones = Self("CalDAV-Timezones")
    /// Close header.
    public static let close = Self("Close")
    /// Content-Base header.
    public static let contentBase = Self("Content-Base")
    /// Content-ID header.
    public static let contentID = Self("Content-ID")
    /// Content-MD5 header.
    public static let contentMD5 = Self("Content-MD5")
    /// Content-Script-Type header.
    public static let contentScriptType = Self("Content-Script-Type")
    /// Content-Style-Type header.
    public static let contentStyleType = Self("Content-Style-Type")
    /// Content-Version header.
    public static let contentVersion = Self("Content-Version")
    /// Cookie2 header.
    public static let cookie2 = Self("Cookie2")
    /// DASL header.
    public static let dasl = Self("DASL")
    /// DASV header.
    public static let dav = Self("DAV")
    /// Default-Style header.
    public static let defaultStyle = Self("Default-Style")
    /// Delta-Base header.
    public static let deltaBase = Self("Delta-Base")
    /// Depth header.
    public static let depth = Self("Depth")
    /// Derived-From header.
    public static let derivedFrom = Self("Derived-From")
    /// Destination header.
    public static let destination = Self("Destination")
    /// Differential-ID header.
    public static let differentialID = Self("Differential-ID")
    /// Digest header.
    public static let digest = Self("Digest")
    /// Ext header.
    public static let ext = Self("Ext")
    /// Forwarded header.
    public static let forwarded = Self("Forwarded")
    /// GetProfile header.
    public static let getProfile = Self("GetProfile")
    /// Hobareg header.
    public static let hobareg = Self("Hobareg")
    /// HTTP2-Settings header.
    public static let http2Settings = Self("HTTP2-Settings")
    /// IM header.
    public static let im = Self("IM")
    /// If header.
    public static let `if` = Self("If")
    /// If-Schedule-Tag-Match header.
    public static let ifScheduleTagMatch = Self("If-Schedule-Tag-Match")
    /// Keep-Alive header.
    public static let keepAlive = Self("Keep-Alive")
    /// Label header.
    public static let label = Self("Label")
    /// Link header.
    public static let link = Self("Link")
    /// Lock-Token header.
    public static let lockToken = Self("Lock-Token")
    /// Man header.
    public static let man = Self("Man")
    /// Memento-Datetime header.
    public static let mementoDatetime = Self("Memento-Datetime")
    /// Meter header.
    public static let meter = Self("Meter")
    /// MIME-Version header.
    public static let mimeVersion = Self("MIME-Version")
    /// Negotiate header.
    public static let negotiate = Self("Negotiate")
    /// Opt header.
    public static let opt = Self("Opt")
    /// Optional-WWW-Authenticate header.
    public static let optionalWWWAuthenticate = Self("Optional-WWW-Authenticate")
    /// Ordering-Type header.
    public static let orderingType = Self("Ordering-Type")
    /// Overwrite header.
    public static let overwrite = Self("Overwrite")
    /// P3P header.
    public static let p3p = Self("P3P")
    /// PEP header.
    public static let pep = Self("PEP")
    /// PICS-Label header.
    public static let picsLabel = Self("PICS-Label")
    /// Pep-Info header.
    public static let pepInfo = Self("Pep-Info")
    /// Position header.
    public static let position = Self("Position")
    /// Pragma header.
    public static let pragma = Self("Pragma")
    /// Prefer header.
    public static let prefer = Self("Prefer")
    /// Preference-Applied header.
    public static let preferenceApplied = Self("Preference-Applied")
    /// ProfileObject header.
    public static let profileObject = Self("ProfileObject")
    /// Protocol header.
    public static let `protocol` = Self("Protocol")
    /// Protocol-Info header.
    public static let protocolInfo = Self("Protocol-Info")
    /// Protocol-Query header.
    public static let protocolQuery = Self("Protocol-Query")
    /// Protocol-Request header.
    public static let protocolRequest = Self("Protocol-Request")
    /// Proxy-Features header.
    public static let proxyFeatures = Self("Proxy-Features")
    /// Proxy-Instruction header.
    public static let proxyInstruction = Self("Proxy-Instruction")
    /// Public header.
    public static let `public` = Self("Public")
    /// Public-Key-Pins header.
    public static let publicKeyPins = Self("Public-Key-Pins")
    /// Public-Key-Pins-Report-Only header.
    public static let publicKeyPinsReportOnly = Self("Public-Key-Pins-Report-Only")
    /// Redirect-Ref header.
    public static let redirectRef = Self("Redirect-Ref")
    /// Safe header.
    public static let safe = Self("Safe")
    /// Schedule-Reply header.
    public static let scheduleReply = Self("Schedule-Reply")
    /// Schedule-Tag header.
    public static let scheduleTag = Self("Schedule-Tag")
    /// Security-Scheme header.
    public static let securityScheme = Self("Security-Scheme")
    /// Set-Cookie2 header.
    public static let setCookie2 = Self("Set-Cookie2")
    /// SetProfile header.
    public static let setProfile = Self("SetProfile")
    /// SLUG header.
    public static let slug = Self("SLUG")
    /// SoapAction header.
    public static let soapAction = Self("SoapAction")
    /// Status-URI header.
    public static let statusURI = Self("Status-URI")
    /// Surrogate-Capability header.
    public static let surrogateCapability = Self("Surrogate-Capability")
    /// Surrogate-Control header.
    public static let surrogateControl = Self("Surrogate-Control")
    /// TCN header.
    public static let tcn = Self("TCN")
    /// Timeout header.
    public static let timeout = Self("Timeout")
    /// Topic header.
    public static let topic = Self("Topic")
    /// TTL header.
    public static let ttl = Self("TTL")
    /// Urgency header.
    public static let urgency = Self("Urgency")
    /// URI header.
    public static let uri = Self("URI")
    /// Variant-Vary header.
    public static let variantVary = Self("Variant-Vary")
    /// Want-Digest header.
    public static let wantDigest = Self("Want-Digest")
    /// Warning header.
    public static let warning = Self("Warning")
    /// X-Frame-Options header.
    public static let xFrameOptions = Self("X-Frame-Options")
    /// X-XSS-Protection header
    public static let xssProtection = Self("X-XSS-Protection")

    // https://www.iana.org/assignments/message-headers/message-headers.xhtml
    // Provisional Message Header Field Names
    /// Access-Control header.
    public static let accessControl = Self("Access-Control")
    /// Compliance header.
    public static let compliance = Self("Compliance")
    /// Content-Transfer-Encoding header.
    public static let contentTransferEncoding = Self("Content-Transfer-Encoding")
    /// Cost header.
    public static let cost = Self("Cost")
    /// EDIINT-Features header.
    public static let ediintFeatures = Self("EDIINT-Features")
    /// Message-ID header.
    public static let messageID = Self("Message-ID")
    /// Method-Check header.
    public static let methodCheck = Self("Method-Check")
    /// Method-Check-Expires header.
    public static let methodCheckExpires = Self("Method-Check-Expires")
    /// Non-Compliance header.
    public static let nonCompliance = Self("Non-Compliance")
    /// Optional header.
    public static let optional = Self("Optional")
    /// Referer-Root header.
    public static let refererRoot = Self("Referer-Root")
    /// Resolution-Hint header.
    public static let resolutionHint = Self("Resolution-Hint")
    /// Resolver-Location header.
    public static let resolverLocation = Self("Resolver-Location")
    /// SubOK header.
    public static let subOK = Self("SubOK")
    /// Subst header.
    public static let subst = Self("Subst")
    /// Title header.
    public static let title = Self("Title")
    /// UA-Color header.
    public static let uaColor = Self("UA-Color")
    /// UA-Media header.
    public static let uaMedia = Self("UA-Media")
    /// UA-Pixels header.
    public static let uaPixels = Self("UA-Pixels")
    /// UA-Resolution header.
    public static let uaResolution = Self("UA-Resolution")
    /// UA-Windowpixels header.
    public static let uaWindowpixels = Self("UA-Windowpixels")
    /// Version header.
    public static let version = Self("Version")
    /// X-Device-Accept header.
    public static let xDeviceAccept = Self("X-Device-Accept")
    /// X-Device-Accept-Charset header.
    public static let xDeviceAcceptCharset = Self("X-Device-Accept-Charset")
    /// X-Device-Accept-Encoding header.
    public static let xDeviceAcceptEncoding = Self("X-Device-Accept-Encoding")
    /// X-Device-Accept-Language header.
    public static let xDeviceAcceptLanguage = Self("X-Device-Accept-Language")
    /// X-Device-User-Agent header.
    public static let xDeviceUserAgent = Self("X-Device-User-Agent")
    /// X-Requested-With header.
    public static let xRequestedWith = Self("X-Requested-With")
    /// X-Forwarded-For header.
    public static let xForwardedFor = Self("X-Forwarded-For")
    /// X-Forwarded-Host header.
    public static let xForwardedHost = Self("X-Forwarded-Host")
    /// X-Forwarded-Proto header.
    public static let xForwardedProto = Self("X-Forwarded-Proto")
    /// X-Request-Id header.
    public static let xRequestId = Self("X-Request-Id")
}


#warning("Do we need this?")
//extension HTTPFields {
//
//    /// Add a header name/value pair to the block.
//    ///
//    /// This method is strictly additive: if there are other values for the given header name
//    /// already in the block, this will add a new entry. `add` performs case-insensitive
//    /// comparisons on the header field name.
//    ///
//    /// - Parameter name: The header field name. For maximum compatibility this should be an
//    ///     ASCII string. For future-proofing with HTTP/2 lowercase header names are strongly
//    //      recommended.
//    /// - Parameter value: The header field value to add for the given name.
//    public mutating func add(name: HTTPField.Name, value: String) {
//       self.add(name: name.lowercased, value: value)
//    }
//    
//    /// Add a header name/value pair to the block, replacing any previous values for the
//    /// same header name that are already in the block.
//    ///
//    /// This is a supplemental method to `add` that essentially combines `remove` and `add`
//    /// in a single function. It can be used to ensure that a header block is in a
//    /// well-defined form without having to check whether the value was previously there.
//    /// Like `add`, this method performs case-insensitive comparisons of the header field
//    /// names.
//    ///
//    /// - Parameter name: The header field name. For maximum compatibility this should be an
//    ///     ASCII string. For future-proofing with HTTP/2 lowercase header names are strongly
//    //      recommended.
//    /// - Parameter value: The header field value to add for the given name.
//    public mutating func replaceOrAdd(name: HTTPField.Name, value: String) {
//        self.replaceOrAdd(name: name.lowercased, value: value)
//    }
//    
//    /// Remove all values for a given header name from the block.
//    ///
//    /// This method uses case-insensitive comparisons for the header field name.
//    ///
//    /// - Parameter name: The name of the header field to remove from the block.
//    public mutating func remove(name: HTTPField.Name) {
//        self.remove(name: name.lowercased)
//    }
//    
//    /// Retrieve all of the values for a given header field name from the block.
//    ///
//    /// This method uses case-insensitive comparisons for the header field name. It
//    /// does not return a maximally-decomposed list of the header fields, but instead
//    /// returns them in their original representation: that means that a comma-separated
//    /// header field list may contain more than one entry, some of which contain commas
//    /// and some do not. If you want a representation of the header fields suitable for
//    /// performing computation on, consider `getCanonicalForm`.
//    ///
//    /// - Parameter name: The header field name whose values are to be retrieved.
//    /// - Returns: A list of the values for that header field name.
//    public subscript(name: HTTPField.Name) -> [String] {
//        self[name.lowercased]
//    }
//    
//    /// Returns `true` if the `HTTPFields` contains a value for the supplied name.
//    /// - Parameter name: The header field name to check.
//    public func contains(name: HTTPField.Name) -> Bool {
//        self.contains(name: name.lowercased)
//    }
//    
//    /// Returns the first header value with the supplied name.
//    /// - Parameter name: The header field name whose values are to be retrieved.
//    public func first(name: HTTPField.Name) -> String? {
//        self.first(name: name.lowercased)
//    }
//
//    public subscript(canonicalForm name: HTTPField.Name) -> [Substring] {
//        self[canonicalForm: name.lowercased]
//    }
//}

// MARK: Internal Vapor Marker Headers
extension HTTPField.Name {
    public static let xVaporResponseCompression = Self("X-Vapor-Response-Compression")
}
