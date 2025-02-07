import NIOHTTP1

extension HTTPHeaders {
    /// Type used for the name of a HTTP header in the `HTTPHeaders` storage.
    public struct Name: Codable, Hashable, Equatable, CustomStringConvertible, ExpressibleByStringLiteral, Sendable {
        /// See `Hashable`
        public func hash(into hasher: inout Hasher) {
            self.lowercased.hash(into: &hasher)
        }

        /// Lowercased-ASCII version of the header.
        internal let lowercased: String

        /// Create a HTTP header name with the provided String.
        public init(_ name: String) {
            self.lowercased = name.lowercased()
        }

        /// `ExpressibleByStringLiteral` conformance.
        public init(stringLiteral: String) {
            self.init(stringLiteral)
        }

        /// See `CustomStringConvertible.description`
        public var description: String {
            return lowercased
        }

        // https://www.iana.org/assignments/message-headers/message-headers.xhtml
        // Permanent Message Header Field Names

        /// A-IM header.
        public static let aIM = Name("A-IM")
        /// Accept header.
        public static let accept = Name("Accept")
        /// Accept-Additions header.
        public static let acceptAdditions = Name("Accept-Additions")
        /// Accept-Charset header.
        public static let acceptCharset = Name("Accept-Charset")
        /// Accept-Datetime header.
        public static let acceptDatetime = Name("Accept-Datetime")
        /// Accept-Encoding header.
        public static let acceptEncoding = Name("Accept-Encoding")
        /// Accept-Features header.
        public static let acceptFeatures = Name("Accept-Features")
        /// Accept-Language header.
        public static let acceptLanguage = Name("Accept-Language")
        /// Accept-Patch header.
        public static let acceptPatch = Name("Accept-Patch")
        /// Accept-Post header.
        public static let acceptPost = Name("Accept-Post")
        /// Accept-Ranges header.
        public static let acceptRanges = Name("Accept-Ranges")
        /// Accept-Age header.
        public static let age = Name("Age")
        /// Accept-Allow header.
        public static let allow = Name("Allow")
        /// ALPN header.
        public static let alpn = Name("ALPN")
        /// Alt-Svc header.
        public static let altSvc = Name("Alt-Svc")
        /// Alt-Used header.
        public static let altUsed = Name("Alt-Used")
        /// Alternates header.
        public static let alternates = Name("Alternates")
        /// Apply-To-Redirect-Ref header.
        public static let applyToRedirectRef = Name("Apply-To-Redirect-Ref")
        /// Authentication-Control header.
        public static let authenticationControl = Name("Authentication-Control")
        /// Authentication-Info header.
        public static let authenticationInfo = Name("Authentication-Info")
        /// Authorization header.
        public static let authorization = Name("Authorization")
        /// C-Ext header.
        public static let cExt = Name("C-Ext")
        /// C-Man header.
        public static let cMan = Name("C-Man")
        /// C-Opt header.
        public static let cOpt = Name("C-Opt")
        /// C-PEP header.
        public static let cPEP = Name("C-PEP")
        /// C-PEP-Info header.
        public static let cPEPInfo = Name("C-PEP-Info")
        /// Cache-Control header.
        public static let cacheControl = Name("Cache-Control")
        /// CalDav-Timezones header.
        public static let calDAVTimezones = Name("CalDAV-Timezones")
        /// Close header.
        public static let close = Name("Close")
        /// Connection header.
        public static let connection = Name("Connection")
        /// Content-Base header.
        public static let contentBase = Name("Content-Base")
        /// Content-Disposition header.
        public static let contentDisposition = Name("Content-Disposition")
        /// Content-Encoding header.
        public static let contentEncoding = Name("Content-Encoding")
        /// Content-ID header.
        public static let contentID = Name("Content-ID")
        /// Content-Language header.
        public static let contentLanguage = Name("Content-Language")
        /// Content-Length header.
        public static let contentLength = Name("Content-Length")
        /// Content-Location header.
        public static let contentLocation = Name("Content-Location")
        /// Content-MD5 header.
        public static let contentMD5 = Name("Content-MD5")
        /// Content-Range header.
        public static let contentRange = Name("Content-Range")
        /// Content-Script-Type header.
        public static let contentScriptType = Name("Content-Script-Type")
        /// Content-Security-Policy
        public static let contentSecurityPolicy = Name("Content-Security-Policy")
        /// Content-Style-Type header.
        public static let contentStyleType = Name("Content-Style-Type")
        /// Content-Type header.
        public static let contentType = Name("Content-Type")
        /// Content-Version header.
        public static let contentVersion = Name("Content-Version")
        /// Cookie header.
        public static let cookie = Name("Cookie")
        /// Cookie2 header.
        public static let cookie2 = Name("Cookie2")
        /// DASL header.
        public static let dasl = Name("DASL")
        /// DASV header.
        public static let dav = Name("DAV")
        /// Date header.
        public static let date = Name("Date")
        /// Default-Style header.
        public static let defaultStyle = Name("Default-Style")
        /// Delta-Base header.
        public static let deltaBase = Name("Delta-Base")
        /// Depth header.
        public static let depth = Name("Depth")
        /// Derived-From header.
        public static let derivedFrom = Name("Derived-From")
        /// Destination header.
        public static let destination = Name("Destination")
        /// Differential-ID header.
        public static let differentialID = Name("Differential-ID")
        /// Digest header.
        public static let digest = Name("Digest")
        /// ETag header.
        public static let eTag = Name("ETag")
        /// Expect header.
        public static let expect = Name("Expect")
        /// Expires header.
        public static let expires = Name("Expires")
        /// Ext header.
        public static let ext = Name("Ext")
        /// Forwarded header.
        public static let forwarded = Name("Forwarded")
        /// From header.
        public static let from = Name("From")
        /// GetProfile header.
        public static let getProfile = Name("GetProfile")
        /// Hobareg header.
        public static let hobareg = Name("Hobareg")
        /// Host header.
        public static let host = Name("Host")
        /// HTTP2-Settings header.
        public static let http2Settings = Name("HTTP2-Settings")
        /// IM header.
        public static let im = Name("IM")
        /// If header.
        public static let `if` = Name("If")
        /// If-Match header.
        public static let ifMatch = Name("If-Match")
        /// If-Modified-Since header.
        public static let ifModifiedSince = Name("If-Modified-Since")
        /// If-None-Match header.
        public static let ifNoneMatch = Name("If-None-Match")
        /// If-Range header.
        public static let ifRange = Name("If-Range")
        /// If-Schedule-Tag-Match header.
        public static let ifScheduleTagMatch = Name("If-Schedule-Tag-Match")
        /// If-Unmodified-Since header.
        public static let ifUnmodifiedSince = Name("If-Unmodified-Since")
        /// Keep-Alive header.
        public static let keepAlive = Name("Keep-Alive")
        /// Label header.
        public static let label = Name("Label")
        /// Last-Modified header.
        public static let lastModified = Name("Last-Modified")
        /// Link header.
        public static let link = Name("Link")
        /// Location header.
        public static let location = Name("Location")
        /// Lock-Token header.
        public static let lockToken = Name("Lock-Token")
        /// Man header.
        public static let man = Name("Man")
        /// Max-Forwards header.
        public static let maxForwards = Name("Max-Forwards")
        /// Memento-Datetime header.
        public static let mementoDatetime = Name("Memento-Datetime")
        /// Meter header.
        public static let meter = Name("Meter")
        /// MIME-Version header.
        public static let mimeVersion = Name("MIME-Version")
        /// Negotiate header.
        public static let negotiate = Name("Negotiate")
        /// Opt header.
        public static let opt = Name("Opt")
        /// Optional-WWW-Authenticate header.
        public static let optionalWWWAuthenticate = Name("Optional-WWW-Authenticate")
        /// Ordering-Type header.
        public static let orderingType = Name("Ordering-Type")
        /// Origin header.
        public static let origin = Name("Origin")
        /// Overwrite header.
        public static let overwrite = Name("Overwrite")
        /// P3P header.
        public static let p3p = Name("P3P")
        /// PEP header.
        public static let pep = Name("PEP")
        /// PICS-Label header.
        public static let picsLabel = Name("PICS-Label")
        /// Pep-Info header.
        public static let pepInfo = Name("Pep-Info")
        /// Position header.
        public static let position = Name("Position")
        /// Pragma header.
        public static let pragma = Name("Pragma")
        /// Prefer header.
        public static let prefer = Name("Prefer")
        /// Preference-Applied header.
        public static let preferenceApplied = Name("Preference-Applied")
        /// ProfileObject header.
        public static let profileObject = Name("ProfileObject")
        /// Protocol header.
        public static let `protocol` = Name("Protocol")
        /// Protocol-Info header.
        public static let protocolInfo = Name("Protocol-Info")
        /// Protocol-Query header.
        public static let protocolQuery = Name("Protocol-Query")
        /// Protocol-Request header.
        public static let protocolRequest = Name("Protocol-Request")
        /// Proxy-Authenticate header.
        public static let proxyAuthenticate = Name("Proxy-Authenticate")
        /// Proxy-Authentication-Info header.
        public static let proxyAuthenticationInfo = Name("Proxy-Authentication-Info")
        /// Proxy-Authorization header.
        public static let proxyAuthorization = Name("Proxy-Authorization")
        /// Proxy-Features header.
        public static let proxyFeatures = Name("Proxy-Features")
        /// Proxy-Instruction header.
        public static let proxyInstruction = Name("Proxy-Instruction")
        /// Public header.
        public static let `public` = Name("Public")
        /// Public-Key-Pins header.
        public static let publicKeyPins = Name("Public-Key-Pins")
        /// Public-Key-Pins-Report-Only header.
        public static let publicKeyPinsReportOnly = Name("Public-Key-Pins-Report-Only")
        /// Range header.
        public static let range = Name("Range")
        /// Redirect-Ref header.
        public static let redirectRef = Name("Redirect-Ref")
        /// Referer header.
        public static let referer = Name("Referer")
        /// Retry-After header.
        public static let retryAfter = Name("Retry-After")
        /// Safe header.
        public static let safe = Name("Safe")
        /// Schedule-Reply header.
        public static let scheduleReply = Name("Schedule-Reply")
        /// Schedule-Tag header.
        public static let scheduleTag = Name("Schedule-Tag")
        /// Sec-WebSocket-Accept header.
        public static let secWebSocketAccept = Name("Sec-WebSocket-Accept")
        /// Sec-WebSocket-Extensions header.
        public static let secWebSocketExtensions = Name("Sec-WebSocket-Extensions")
        /// Sec-WebSocket-Key header.
        public static let secWebSocketKey = Name("Sec-WebSocket-Key")
        /// Sec-WebSocket-Protocol header.
        public static let secWebSocketProtocol = Name("Sec-WebSocket-Protocol")
        /// Sec-WebSocket-Version header.
        public static let secWebSocketVersion = Name("Sec-WebSocket-Version")
        /// Security-Scheme header.
        public static let securityScheme = Name("Security-Scheme")
        /// Server header.
        public static let server = Name("Server")
        /// Set-Cookie header.
        public static let setCookie = Name("Set-Cookie")
        /// Set-Cookie2 header.
        public static let setCookie2 = Name("Set-Cookie2")
        /// SetProfile header.
        public static let setProfile = Name("SetProfile")
        /// SLUG header.
        public static let slug = Name("SLUG")
        /// SoapAction header.
        public static let soapAction = Name("SoapAction")
        /// Status-URI header.
        public static let statusURI = Name("Status-URI")
        /// Strict-Transport-Security header.
        public static let strictTransportSecurity = Name("Strict-Transport-Security")
        /// Surrogate-Capability header.
        public static let surrogateCapability = Name("Surrogate-Capability")
        /// Surrogate-Control header.
        public static let surrogateControl = Name("Surrogate-Control")
        /// TCN header.
        public static let tcn = Name("TCN")
        /// TE header.
        public static let te = Name("TE")
        /// Timeout header.
        public static let timeout = Name("Timeout")
        /// Topic header.
        public static let topic = Name("Topic")
        /// Trailer header.
        public static let trailer = Name("Trailer")
        /// Transfer-Encoding header.
        public static let transferEncoding = Name("Transfer-Encoding")
        /// TTL header.
        public static let ttl = Name("TTL")
        /// Urgency header.
        public static let urgency = Name("Urgency")
        /// URI header.
        public static let uri = Name("URI")
        /// Upgrade header.
        public static let upgrade = Name("Upgrade")
        /// User-Agent header.
        public static let userAgent = Name("User-Agent")
        /// Variant-Vary header.
        public static let variantVary = Name("Variant-Vary")
        /// Vary header.
        public static let vary = Name("Vary")
        /// Via header.
        public static let via = Name("Via")
        /// WWW-Authenticate header.
        public static let wwwAuthenticate = Name("WWW-Authenticate")
        /// Want-Digest header.
        public static let wantDigest = Name("Want-Digest")
        /// Warning header.
        public static let warning = Name("Warning")
        /// X-Content-Type-Options
        public static let xContentTypeOptions = Name("X-Content-Type-Options")
        /// X-Frame-Options header.
        public static let xFrameOptions = Name("X-Frame-Options")
        /// X-XSS-Protection header
        public static let xssProtection = Name("X-XSS-Protection")

        // https://www.iana.org/assignments/message-headers/message-headers.xhtml
        // Provisional Message Header Field Names
        /// Access-Control header.
        public static let accessControl = Name("Access-Control")
        /// Access-Control-Allow-Credentials header.
        public static let accessControlAllowCredentials = Name("Access-Control-Allow-Credentials")
        /// Access-Control-Allow-Headers header.
        public static let accessControlAllowHeaders = Name("Access-Control-Allow-Headers")
        /// Access-Control-Allow-Methods header.
        public static let accessControlAllowMethods = Name("Access-Control-Allow-Methods")
        /// Access-Control-Allow-Origin header.
        public static let accessControlAllowOrigin = Name("Access-Control-Allow-Origin")
        /// Access-Control-Expose-Headers header.
        public static let accessControlExpose = Name("Access-Control-Expose-Headers")
        /// Access-Control-Max-Age header.
        public static let accessControlMaxAge = Name("Access-Control-Max-Age")
        /// Access-Control-Request-Method header.
        public static let accessControlRequestMethod = Name("Access-Control-Request-Method")
        /// Access-Control-Request-Headers header.
        public static let accessControlRequestHeaders = Name("Access-Control-Request-Headers")
        /// Compliance header.
        public static let compliance = Name("Compliance")
        /// Content-Transfer-Encoding header.
        public static let contentTransferEncoding = Name("Content-Transfer-Encoding")
        /// Cost header.
        public static let cost = Name("Cost")
        /// EDIINT-Features header.
        public static let ediintFeatures = Name("EDIINT-Features")
        /// Message-ID header.
        public static let messageID = Name("Message-ID")
        /// Method-Check header.
        public static let methodCheck = Name("Method-Check")
        /// Method-Check-Expires header.
        public static let methodCheckExpires = Name("Method-Check-Expires")
        /// Non-Compliance header.
        public static let nonCompliance = Name("Non-Compliance")
        /// Optional header.
        public static let optional = Name("Optional")
        /// Referer-Root header.
        public static let refererRoot = Name("Referer-Root")
        /// Resolution-Hint header.
        public static let resolutionHint = Name("Resolution-Hint")
        /// Resolver-Location header.
        public static let resolverLocation = Name("Resolver-Location")
        /// SubOK header.
        public static let subOK = Name("SubOK")
        /// Subst header.
        public static let subst = Name("Subst")
        /// Title header.
        public static let title = Name("Title")
        /// UA-Color header.
        public static let uaColor = Name("UA-Color")
        /// UA-Media header.
        public static let uaMedia = Name("UA-Media")
        /// UA-Pixels header.
        public static let uaPixels = Name("UA-Pixels")
        /// UA-Resolution header.
        public static let uaResolution = Name("UA-Resolution")
        /// UA-Windowpixels header.
        public static let uaWindowpixels = Name("UA-Windowpixels")
        /// Version header.
        public static let version = Name("Version")
        /// X-Device-Accept header.
        public static let xDeviceAccept = Name("X-Device-Accept")
        /// X-Device-Accept-Charset header.
        public static let xDeviceAcceptCharset = Name("X-Device-Accept-Charset")
        /// X-Device-Accept-Encoding header.
        public static let xDeviceAcceptEncoding = Name("X-Device-Accept-Encoding")
        /// X-Device-Accept-Language header.
        public static let xDeviceAcceptLanguage = Name("X-Device-Accept-Language")
        /// X-Device-User-Agent header.
        public static let xDeviceUserAgent = Name("X-Device-User-Agent")
        /// X-Requested-With header.
        public static let xRequestedWith = Name("X-Requested-With")
        /// X-Forwarded-For header.
        public static let xForwardedFor = Name("X-Forwarded-For")
        /// X-Forwarded-Host header.
        public static let xForwardedHost = Name("X-Forwarded-Host")
        /// X-Forwarded-Proto header.
        public static let xForwardedProto = Name("X-Forwarded-Proto")
        /// X-Request-Id header.
        public static let xRequestId = Name("X-Request-Id")
    }

    /// Add a header name/value pair to the block.
    ///
    /// This method is strictly additive: if there are other values for the given header name
    /// already in the block, this will add a new entry. `add` performs case-insensitive
    /// comparisons on the header field name.
    ///
    /// - Parameter name: The header field name. For maximum compatibility this should be an
    ///     ASCII string. For future-proofing with HTTP/2 lowercase header names are strongly
    //      recommended.
    /// - Parameter value: The header field value to add for the given name.
    public mutating func add(name: Name, value: String) {
        self.add(name: name.lowercased, value: value)
    }

    /// Add a header name/value pair to the block, replacing any previous values for the
    /// same header name that are already in the block.
    ///
    /// This is a supplemental method to `add` that essentially combines `remove` and `add`
    /// in a single function. It can be used to ensure that a header block is in a
    /// well-defined form without having to check whether the value was previously there.
    /// Like `add`, this method performs case-insensitive comparisons of the header field
    /// names.
    ///
    /// - Parameter name: The header field name. For maximum compatibility this should be an
    ///     ASCII string. For future-proofing with HTTP/2 lowercase header names are strongly
    //      recommended.
    /// - Parameter value: The header field value to add for the given name.
    public mutating func replaceOrAdd(name: Name, value: String) {
        self.replaceOrAdd(name: name.lowercased, value: value)
    }

    /// Remove all values for a given header name from the block.
    ///
    /// This method uses case-insensitive comparisons for the header field name.
    ///
    /// - Parameter name: The name of the header field to remove from the block.
    public mutating func remove(name: Name) {
        self.remove(name: name.lowercased)
    }

    /// Retrieve all of the values for a given header field name from the block.
    ///
    /// This method uses case-insensitive comparisons for the header field name. It
    /// does not return a maximally-decomposed list of the header fields, but instead
    /// returns them in their original representation: that means that a comma-separated
    /// header field list may contain more than one entry, some of which contain commas
    /// and some do not. If you want a representation of the header fields suitable for
    /// performing computation on, consider `getCanonicalForm`.
    ///
    /// - Parameter name: The header field name whose values are to be retrieved.
    /// - Returns: A list of the values for that header field name.
    public subscript(name: Name) -> [String] {
        self[name.lowercased]
    }

    /// Returns `true` if the `HTTPHeaders` contains a value for the supplied name.
    /// - Parameter name: The header field name to check.
    public func contains(name: Name) -> Bool {
        self.contains(name: name.lowercased)
    }

    /// Returns the first header value with the supplied name.
    /// - Parameter name: The header field name whose values are to be retrieved.
    public func first(name: Name) -> String? {
        self.first(name: name.lowercased)
    }

    public subscript(canonicalForm name: Name) -> [Substring] {
        self[canonicalForm: name.lowercased]
    }
}

extension NIOHTTP1.HTTPHeaders: Swift.CustomDebugStringConvertible {
    /// See `CustomDebugStringConvertible.debugDescription`
    public var debugDescription: String {
        var desc: [String] = []
        for (key, val) in self {
            desc.append("\(key): \(val)")
        }
        return desc.joined(separator: "\n")
    }
}

// MARK: Internal Vapor Marker Headers
extension HTTPHeaders.Name {
    public static let xVaporResponseCompression = Self("X-Vapor-Response-Compression")
}
