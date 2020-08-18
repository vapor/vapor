/// Represents an encoded data-format, used in HTTP, HTML, email, and elsewhere.
///
///     text/plain
///     application/json; charset=utf8
///
/// Description from [rfc2045](https://tools.ietf.org/html/rfc2045#section-5):
///
///     In general, the top-level media type is used to declare the general
///     type of data, while the subtype specifies a specific format for that
///     type of data.  Thus, a media type of "image/xyz" is enough to tell a
///     user agent that the data is an image, even if the user agent has no
///     knowledge of the specific image format "xyz".  Such information can
///     be used, for example, to decide whether or not to show a user the raw
///     data from an unrecognized subtype -- such an action might be
///     reasonable for unrecognized subtypes of text, but not for
///     unrecognized subtypes of image or audio.  For this reason, registered
///     subtypes of text, image, audio, and video should not contain embedded
///     information that is really of a different type.  Such compound
///     formats should be represented using the "multipart" or "application"
///     types.
///
/// Simplified format:
///
///     mediaType := type "/" subtype *(";" parameter)
///     ; Matching of media type and subtype
///     ; is ALWAYS case-insensitive.
///
///     type := token
///
///     subtype := token
///
///     parameter := attribute "=" value
///
///     attribute := token
///     ; Matching of attributes
///     ; is ALWAYS case-insensitive.
///
///     token := 1*<any (US-ASCII) CHAR except SPACE, CTLs,
///         or tspecials>
///
///     value := token
///     ; token MAY be quoted
///
///     tspecials :=  "(" / ")" / "<" / ">" / "@" /
///                   "," / ";" / ":" / "\" / <">
///                   "/" / "[" / "]" / "?" / "="
///     ; Must be in quoted-string,
///     ; to use within parameter values
///
public struct HTTPMediaType: Hashable, CustomStringConvertible, Equatable {
    /// See `Equatable`.
    public static func ==(lhs: HTTPMediaType, rhs: HTTPMediaType) -> Bool {
        guard lhs.type != "*" && rhs.type != "*" else {
            return true
        }

        guard lhs.type.caseInsensitiveCompare(rhs.type) == .orderedSame else {
            return false
        }

        return lhs.subType == "*" || rhs.subType == "*" || lhs.subType.caseInsensitiveCompare(rhs.subType) == .orderedSame
    }
    
    /// The `MediaType`'s discrete or composite type. Usually one of the following.
    ///
    ///     "text" / "image" / "audio" / "video" / "application
    ///     "message" / "multipart"
    ///     ...
    ///
    /// In the `MediaType` `"application/json; charset=utf8"`:
    ///
    /// - type: `"application"`
    /// - subtype: `"json"`
    /// - parameters: ["charset": "utf8"]
    public var type: String
    
    /// The `MediaType`'s specific type. Usually a unique string.
    ///
    /// In the `MediaType` `"application/json; charset=utf8"`:
    ///
    /// - type: `"application"`
    /// - subtype: `"json"`
    /// - parameters: ["charset": "utf8"]
    public var subType: String
    
    /// The `MediaType`'s metadata. Zero or more key/value pairs.
    ///
    /// In the `MediaType` `"application/json; charset=utf8"`:
    ///
    /// - type: `"application"`
    /// - subtype: `"json"`
    /// - parameters: ["charset": "utf8"]
    public var parameters: [String: String]
    
    /// Converts this `MediaType` into its string representation.
    ///
    /// For example, the following media type:
    ///
    /// - type: `"application"`
    /// - subtype: `"json"`
    /// - parameters: ["charset": "utf8"]
    ///
    /// Would be converted to `"application/json; charset=utf8"`.
    public func serialize() -> String {
        var string = "\(type)/\(subType)"
        for (key, val) in parameters {
            string += "; \(key)=\(val)"
        }
        return string
    }
    
    /// See `CustomStringConvertible`.
    public var description: String {
        return serialize()
    }
    
    /// See `Hashable`.
    public func hash(into hasher: inout Hasher) {
        self.type.hash(into: &hasher)
        self.subType.hash(into: &hasher)
    }
    
    /// Create a new `MediaType`.
    public init(type: String, subType: String, parameters: [String: String] = [:]) {
        self.type = type
        self.subType = subType
        self.parameters = parameters
    }
    
    /// Parse a `MediaType` from directives.
    init?(directives: [HTTPHeaders.Directive]) {
        guard let value = directives.first, value.parameter == nil else {
            /// not a valid header value
            return nil
        }

        /// parse out type and subtype
        let typeParts = value.value.split(separator: "/", maxSplits: 2)
        guard typeParts.count == 2 else {
            /// the type was not form `foo/bar`
            return nil
        }

        self.type = String(typeParts[0]).trimmingCharacters(in: .whitespaces)
        self.subType = String(typeParts[1]).trimmingCharacters(in: .whitespaces)

        self.parameters = [:]
        for directive in directives[1...] {
            guard let parameter = directive.parameter else {
                return nil
            }
            self.parameters[.init(directive.value)] = .init(parameter)
        }
    }
    
    /// Creates a `MediaType` from a file extension, if possible.
    ///
    ///     guard let mediaType = MediaType.fileExtension("txt") else { ... }
    ///
    /// - parameters:
    ///     - ext: File extension (ie., "txt", "json", "html").
    /// - returns: Newly created `MediaType`, `nil` if none was found.
    public static func fileExtension(_ ext: String) -> HTTPMediaType? {
        return fileExtensionMediaTypeMapping[ext]
    }
}

public extension HTTPMediaType {
    /// Any media type (*/*).
    static let any = HTTPMediaType(type: "*", subType: "*")
    /// Plain text media type.
    static let plainText = HTTPMediaType(type: "text", subType: "plain", parameters: ["charset": "utf-8"])
    /// HTML media type.
    static let html = HTTPMediaType(type: "text", subType: "html", parameters: ["charset": "utf-8"])
    /// CSS media type.
    static let css = HTTPMediaType(type: "text", subType: "css", parameters: ["charset": "utf-8"])
    /// URL encoded form media type.
    static let urlEncodedForm = HTTPMediaType(type: "application", subType: "x-www-form-urlencoded", parameters: ["charset": "utf-8"])
    /// Multipart encoded form data.
    static let formData = HTTPMediaType(type: "multipart", subType: "form-data")
    // Multipart encoded form data with boundary.
    static func formData(boundary: String) -> HTTPMediaType {
        .init(type: "multipart", subType: "form-data", parameters: [
            "boundary": boundary
        ])
    }
    /// Mixed multipart encoded data.
    static let multipart = HTTPMediaType(type: "multipart", subType: "mixed")
    /// JSON media type.
    static let json = HTTPMediaType(type: "application", subType: "json", parameters: ["charset": "utf-8"])
    /// JSON API media type (see https://jsonapi.org/format/).
    static let jsonAPI = HTTPMediaType(type: "application", subType: "vnd.api+json", parameters: ["charset": "utf-8"])
    /// XML media type.
    static let xml = HTTPMediaType(type: "application", subType: "xml", parameters: ["charset": "utf-8"])
    /// DTD media type.
    static let dtd = HTTPMediaType(type: "application", subType: "xml-dtd", parameters: ["charset": "utf-8"])
    /// PDF data.
    static let pdf = HTTPMediaType(type: "application", subType: "pdf")
    /// Zip file.
    static let zip = HTTPMediaType(type: "application", subType: "zip")
    /// tar file.
    static let tar = HTTPMediaType(type: "application", subType: "x-tar")
    /// Gzip file.
    static let gzip = HTTPMediaType(type: "application", subType: "x-gzip")
    /// Bzip2 file.
    static let bzip2 = HTTPMediaType(type: "application", subType: "x-bzip2")
    /// Binary data.
    static let binary = HTTPMediaType(type: "application", subType: "octet-stream")
    /// GIF image.
    static let gif = HTTPMediaType(type: "image", subType: "gif")
    /// JPEG image.
    static let jpeg = HTTPMediaType(type: "image", subType: "jpeg")
    /// PNG image.
    static let png = HTTPMediaType(type: "image", subType: "png")
    /// SVG image.
    static let svg = HTTPMediaType(type: "image", subType: "svg+xml")
    /// Basic audio.
    static let audio = HTTPMediaType(type: "audio", subType: "basic")
    /// MIDI audio.
    static let midi = HTTPMediaType(type: "audio", subType: "x-midi")
    /// MP3 audio.
    static let mp3 = HTTPMediaType(type: "audio", subType: "mpeg")
    /// Wave audio.
    static let wave = HTTPMediaType(type: "audio", subType: "wav")
    /// OGG audio.
    static let ogg = HTTPMediaType(type: "audio", subType: "vorbis")
    /// AVI video.
    static let avi = HTTPMediaType(type: "video", subType: "avi")
    /// MPEG video.
    static let mpeg = HTTPMediaType(type: "video", subType: "mpeg")
}

// MARK: Extensions
let fileExtensionMediaTypeMapping: [String: HTTPMediaType] = [
    "ez": HTTPMediaType(type: "application", subType: "andrew-inset"),
    "anx": HTTPMediaType(type: "application", subType: "annodex"),
    "atom": HTTPMediaType(type: "application", subType: "atom+xml"),
    "atomcat": HTTPMediaType(type: "application", subType: "atomcat+xml"),
    "atomsrv": HTTPMediaType(type: "application", subType: "atomserv+xml"),
    "lin": HTTPMediaType(type: "application", subType: "bbolin"),
    "cu": HTTPMediaType(type: "application", subType: "cu-seeme"),
    "davmount": HTTPMediaType(type: "application", subType: "davmount+xml"),
    "dcm": HTTPMediaType(type: "application", subType: "dicom"),
    "tsp": HTTPMediaType(type: "application", subType: "dsptype"),
    "es": HTTPMediaType(type: "application", subType: "ecmascript"),
    "spl": HTTPMediaType(type: "application", subType: "futuresplash"),
    "hta": HTTPMediaType(type: "application", subType: "hta"),
    "jar": HTTPMediaType(type: "application", subType: "java-archive"),
    "ser": HTTPMediaType(type: "application", subType: "java-serialized-object"),
    "class": HTTPMediaType(type: "application", subType: "java-vm"),
    "js": HTTPMediaType(type: "application", subType: "javascript"),
    "json": HTTPMediaType(type: "application", subType: "json"),
    "m3g": HTTPMediaType(type: "application", subType: "m3g"),
    "hqx": HTTPMediaType(type: "application", subType: "mac-binhex40"),
    "cpt": HTTPMediaType(type: "application", subType: "mac-compactpro"),
    "nb": HTTPMediaType(type: "application", subType: "mathematica"),
    "nbp": HTTPMediaType(type: "application", subType: "mathematica"),
    "mbox": HTTPMediaType(type: "application", subType: "mbox"),
    "mdb": HTTPMediaType(type: "application", subType: "msaccess"),
    "doc": HTTPMediaType(type: "application", subType: "msword"),
    "dot": HTTPMediaType(type: "application", subType: "msword"),
    "mxf": HTTPMediaType(type: "application", subType: "mxf"),
    "bin": HTTPMediaType(type: "application", subType: "octet-stream"),
    "oda": HTTPMediaType(type: "application", subType: "oda"),
    "ogx": HTTPMediaType(type: "application", subType: "ogg"),
    "one": HTTPMediaType(type: "application", subType: "onenote"),
    "onetoc2": HTTPMediaType(type: "application", subType: "onenote"),
    "onetmp": HTTPMediaType(type: "application", subType: "onenote"),
    "onepkg": HTTPMediaType(type: "application", subType: "onenote"),
    "pdf": HTTPMediaType(type: "application", subType: "pdf"),
    "pgp": HTTPMediaType(type: "application", subType: "pgp-encrypted"),
    "key": HTTPMediaType(type: "application", subType: "pgp-keys"),
    "sig": HTTPMediaType(type: "application", subType: "pgp-signature"),
    "prf": HTTPMediaType(type: "application", subType: "pics-rules"),
    "ps": HTTPMediaType(type: "application", subType: "postscript"),
    "ai": HTTPMediaType(type: "application", subType: "postscript"),
    "eps": HTTPMediaType(type: "application", subType: "postscript"),
    "epsi": HTTPMediaType(type: "application", subType: "postscript"),
    "epsf": HTTPMediaType(type: "application", subType: "postscript"),
    "eps2": HTTPMediaType(type: "application", subType: "postscript"),
    "eps3": HTTPMediaType(type: "application", subType: "postscript"),
    "rar": HTTPMediaType(type: "application", subType: "rar"),
    "rdf": HTTPMediaType(type: "application", subType: "rdf+xml"),
    "rtf": HTTPMediaType(type: "application", subType: "rtf"),
    "stl": HTTPMediaType(type: "application", subType: "sla"),
    "smi": HTTPMediaType(type: "application", subType: "smil+xml"),
    "smil": HTTPMediaType(type: "application", subType: "smil+xml"),
    "xhtml": HTTPMediaType(type: "application", subType: "xhtml+xml"),
    "xht": HTTPMediaType(type: "application", subType: "xhtml+xml"),
    "xml": HTTPMediaType(type: "application", subType: "xml"),
    "xsd": HTTPMediaType(type: "application", subType: "xml"),
    "xsl": HTTPMediaType(type: "application", subType: "xslt+xml"),
    "xslt": HTTPMediaType(type: "application", subType: "xslt+xml"),
    "xspf": HTTPMediaType(type: "application", subType: "xspf+xml"),
    "zip": HTTPMediaType(type: "application", subType: "zip"),
    "apk": HTTPMediaType(type: "application", subType: "vnd.android.package-archive"),
    "cdy": HTTPMediaType(type: "application", subType: "vnd.cinderella"),
    "kml": HTTPMediaType(type: "application", subType: "vnd.google-earth.kml+xml"),
    "kmz": HTTPMediaType(type: "application", subType: "vnd.google-earth.kmz"),
    "xul": HTTPMediaType(type: "application", subType: "vnd.mozilla.xul+xml"),
    "xls": HTTPMediaType(type: "application", subType: "vnd.ms-excel"),
    "xlb": HTTPMediaType(type: "application", subType: "vnd.ms-excel"),
    "xlt": HTTPMediaType(type: "application", subType: "vnd.ms-excel"),
    "xlam": HTTPMediaType(type: "application", subType: "vnd.ms-excel.addin.macroEnabled.12"),
    "xlsb": HTTPMediaType(type: "application", subType: "vnd.ms-excel.sheet.binary.macroEnabled.12"),
    "xlsm": HTTPMediaType(type: "application", subType: "vnd.ms-excel.sheet.macroEnabled.12"),
    "xltm": HTTPMediaType(type: "application", subType: "vnd.ms-excel.template.macroEnabled.12"),
    "eot": HTTPMediaType(type: "application", subType: "vnd.ms-fontobject"),
    "thmx": HTTPMediaType(type: "application", subType: "vnd.ms-officetheme"),
    "cat": HTTPMediaType(type: "application", subType: "vnd.ms-pki.seccat"),
    "ppt": HTTPMediaType(type: "application", subType: "vnd.ms-powerpoint"),
    "pps": HTTPMediaType(type: "application", subType: "vnd.ms-powerpoint"),
    "ppam": HTTPMediaType(type: "application", subType: "vnd.ms-powerpoint.addin.macroEnabled.12"),
    "pptm": HTTPMediaType(type: "application", subType: "vnd.ms-powerpoint.presentation.macroEnabled.12"),
    "sldm": HTTPMediaType(type: "application", subType: "vnd.ms-powerpoint.slide.macroEnabled.12"),
    "ppsm": HTTPMediaType(type: "application", subType: "vnd.ms-powerpoint.slideshow.macroEnabled.12"),
    "potm": HTTPMediaType(type: "application", subType: "vnd.ms-powerpoint.template.macroEnabled.12"),
    "docm": HTTPMediaType(type: "application", subType: "vnd.ms-word.document.macroEnabled.12"),
    "dotm": HTTPMediaType(type: "application", subType: "vnd.ms-word.template.macroEnabled.12"),
    "odc": HTTPMediaType(type: "application", subType: "vnd.oasis.opendocument.chart"),
    "odb": HTTPMediaType(type: "application", subType: "vnd.oasis.opendocument.database"),
    "odf": HTTPMediaType(type: "application", subType: "vnd.oasis.opendocument.formula"),
    "odg": HTTPMediaType(type: "application", subType: "vnd.oasis.opendocument.graphics"),
    "otg": HTTPMediaType(type: "application", subType: "vnd.oasis.opendocument.graphics-template"),
    "odi": HTTPMediaType(type: "application", subType: "vnd.oasis.opendocument.image"),
    "odp": HTTPMediaType(type: "application", subType: "vnd.oasis.opendocument.presentation"),
    "otp": HTTPMediaType(type: "application", subType: "vnd.oasis.opendocument.presentation-template"),
    "ods": HTTPMediaType(type: "application", subType: "vnd.oasis.opendocument.spreadsheet"),
    "ots": HTTPMediaType(type: "application", subType: "vnd.oasis.opendocument.spreadsheet-template"),
    "odt": HTTPMediaType(type: "application", subType: "vnd.oasis.opendocument.text"),
    "odm": HTTPMediaType(type: "application", subType: "vnd.oasis.opendocument.text-master"),
    "ott": HTTPMediaType(type: "application", subType: "vnd.oasis.opendocument.text-template"),
    "oth": HTTPMediaType(type: "application", subType: "vnd.oasis.opendocument.text-web"),
    "pptx": HTTPMediaType(type: "application", subType: "vnd.openxmlformats-officedocument.presentationml.presentation"),
    "sldx": HTTPMediaType(type: "application", subType: "vnd.openxmlformats-officedocument.presentationml.slide"),
    "ppsx": HTTPMediaType(type: "application", subType: "vnd.openxmlformats-officedocument.presentationml.slideshow"),
    "potx": HTTPMediaType(type: "application", subType: "vnd.openxmlformats-officedocument.presentationml.template"),
    "xlsx": HTTPMediaType(type: "application", subType: "vnd.openxmlformats-officedocument.spreadsheetml.sheet"),
    "xltx": HTTPMediaType(type: "application", subType: "vnd.openxmlformats-officedocument.spreadsheetml.template"),
    "docx": HTTPMediaType(type: "application", subType: "vnd.openxmlformats-officedocument.wordprocessingml.document"),
    "dotx": HTTPMediaType(type: "application", subType: "vnd.openxmlformats-officedocument.wordprocessingml.template"),
    "cod": HTTPMediaType(type: "application", subType: "vnd.rim.cod"),
    "mmf": HTTPMediaType(type: "application", subType: "vnd.smaf"),
    "sdc": HTTPMediaType(type: "application", subType: "vnd.stardivision.calc"),
    "sds": HTTPMediaType(type: "application", subType: "vnd.stardivision.chart"),
    "sda": HTTPMediaType(type: "application", subType: "vnd.stardivision.draw"),
    "sdd": HTTPMediaType(type: "application", subType: "vnd.stardivision.impress"),
    "sdf": HTTPMediaType(type: "application", subType: "vnd.stardivision.math"),
    "sdw": HTTPMediaType(type: "application", subType: "vnd.stardivision.writer"),
    "sgl": HTTPMediaType(type: "application", subType: "vnd.stardivision.writer-global"),
    "sxc": HTTPMediaType(type: "application", subType: "vnd.sun.xml.calc"),
    "stc": HTTPMediaType(type: "application", subType: "vnd.sun.xml.calc.template"),
    "sxd": HTTPMediaType(type: "application", subType: "vnd.sun.xml.draw"),
    "std": HTTPMediaType(type: "application", subType: "vnd.sun.xml.draw.template"),
    "sxi": HTTPMediaType(type: "application", subType: "vnd.sun.xml.impress"),
    "sti": HTTPMediaType(type: "application", subType: "vnd.sun.xml.impress.template"),
    "sxm": HTTPMediaType(type: "application", subType: "vnd.sun.xml.math"),
    "sxw": HTTPMediaType(type: "application", subType: "vnd.sun.xml.writer"),
    "sxg": HTTPMediaType(type: "application", subType: "vnd.sun.xml.writer.global"),
    "stw": HTTPMediaType(type: "application", subType: "vnd.sun.xml.writer.template"),
    "sis": HTTPMediaType(type: "application", subType: "vnd.symbian.install"),
    "cap": HTTPMediaType(type: "application", subType: "vnd.tcpdump.pcap"),
    "pcap": HTTPMediaType(type: "application", subType: "vnd.tcpdump.pcap"),
    "vsd": HTTPMediaType(type: "application", subType: "vnd.visio"),
    "wbxml": HTTPMediaType(type: "application", subType: "vnd.wap.wbxml"),
    "wmlc": HTTPMediaType(type: "application", subType: "vnd.wap.wmlc"),
    "wmlsc": HTTPMediaType(type: "application", subType: "vnd.wap.wmlscriptc"),
    "wpd": HTTPMediaType(type: "application", subType: "vnd.wordperfect"),
    "wp5": HTTPMediaType(type: "application", subType: "vnd.wordperfect5.1"),
    "wk": HTTPMediaType(type: "application", subType: "x-123"),
    "7z": HTTPMediaType(type: "application", subType: "x-7z-compressed"),
    "abw": HTTPMediaType(type: "application", subType: "x-abiword"),
    "dmg": HTTPMediaType(type: "application", subType: "x-apple-diskimage"),
    "bcpio": HTTPMediaType(type: "application", subType: "x-bcpio"),
    "torrent": HTTPMediaType(type: "application", subType: "x-bittorrent"),
    "cab": HTTPMediaType(type: "application", subType: "x-cab"),
    "cbr": HTTPMediaType(type: "application", subType: "x-cbr"),
    "cbz": HTTPMediaType(type: "application", subType: "x-cbz"),
    "cdf": HTTPMediaType(type: "application", subType: "x-cdf"),
    "cda": HTTPMediaType(type: "application", subType: "x-cdf"),
    "vcd": HTTPMediaType(type: "application", subType: "x-cdlink"),
    "pgn": HTTPMediaType(type: "application", subType: "x-chess-pgn"),
    "mph": HTTPMediaType(type: "application", subType: "x-comsol"),
    "cpio": HTTPMediaType(type: "application", subType: "x-cpio"),
    "csh": HTTPMediaType(type: "application", subType: "x-csh"),
    "deb": HTTPMediaType(type: "application", subType: "x-debian-package"),
    "udeb": HTTPMediaType(type: "application", subType: "x-debian-package"),
    "dcr": HTTPMediaType(type: "application", subType: "x-director"),
    "dir": HTTPMediaType(type: "application", subType: "x-director"),
    "dxr": HTTPMediaType(type: "application", subType: "x-director"),
    "dms": HTTPMediaType(type: "application", subType: "x-dms"),
    "wad": HTTPMediaType(type: "application", subType: "x-doom"),
    "dvi": HTTPMediaType(type: "application", subType: "x-dvi"),
    "pfa": HTTPMediaType(type: "application", subType: "x-font"),
    "pfb": HTTPMediaType(type: "application", subType: "x-font"),
    "gsf": HTTPMediaType(type: "application", subType: "x-font"),
    "pcf": HTTPMediaType(type: "application", subType: "x-font"),
    "pcf.Z": HTTPMediaType(type: "application", subType: "x-font"),
    "woff": HTTPMediaType(type: "application", subType: "x-font-woff"),
    "mm": HTTPMediaType(type: "application", subType: "x-freemind"),
    "gan": HTTPMediaType(type: "application", subType: "x-ganttproject"),
    "gnumeric": HTTPMediaType(type: "application", subType: "x-gnumeric"),
    "sgf": HTTPMediaType(type: "application", subType: "x-go-sgf"),
    "gcf": HTTPMediaType(type: "application", subType: "x-graphing-calculator"),
    "gtar": HTTPMediaType(type: "application", subType: "x-gtar"),
    "tgz": HTTPMediaType(type: "application", subType: "x-gtar-compressed"),
    "taz": HTTPMediaType(type: "application", subType: "x-gtar-compressed"),
    "hdf": HTTPMediaType(type: "application", subType: "x-hdf"),
    "hwp": HTTPMediaType(type: "application", subType: "x-hwp"),
    "ica": HTTPMediaType(type: "application", subType: "x-ica"),
    "info": HTTPMediaType(type: "application", subType: "x-info"),
    "ins": HTTPMediaType(type: "application", subType: "x-internet-signup"),
    "isp": HTTPMediaType(type: "application", subType: "x-internet-signup"),
    "iii": HTTPMediaType(type: "application", subType: "x-iphone"),
    "iso": HTTPMediaType(type: "application", subType: "x-iso9660-image"),
    "jam": HTTPMediaType(type: "application", subType: "x-jam"),
    "jnlp": HTTPMediaType(type: "application", subType: "x-java-jnlp-file"),
    "jmz": HTTPMediaType(type: "application", subType: "x-jmol"),
    "chrt": HTTPMediaType(type: "application", subType: "x-kchart"),
    "kil": HTTPMediaType(type: "application", subType: "x-killustrator"),
    "skp": HTTPMediaType(type: "application", subType: "x-koan"),
    "skd": HTTPMediaType(type: "application", subType: "x-koan"),
    "skt": HTTPMediaType(type: "application", subType: "x-koan"),
    "skm": HTTPMediaType(type: "application", subType: "x-koan"),
    "kpr": HTTPMediaType(type: "application", subType: "x-kpresenter"),
    "kpt": HTTPMediaType(type: "application", subType: "x-kpresenter"),
    "ksp": HTTPMediaType(type: "application", subType: "x-kspread"),
    "kwd": HTTPMediaType(type: "application", subType: "x-kword"),
    "kwt": HTTPMediaType(type: "application", subType: "x-kword"),
    "latex": HTTPMediaType(type: "application", subType: "x-latex"),
    "lha": HTTPMediaType(type: "application", subType: "x-lha"),
    "lyx": HTTPMediaType(type: "application", subType: "x-lyx"),
    "lzh": HTTPMediaType(type: "application", subType: "x-lzh"),
    "lzx": HTTPMediaType(type: "application", subType: "x-lzx"),
    "frm": HTTPMediaType(type: "application", subType: "x-maker"),
    "maker": HTTPMediaType(type: "application", subType: "x-maker"),
    "frame": HTTPMediaType(type: "application", subType: "x-maker"),
    "fm": HTTPMediaType(type: "application", subType: "x-maker"),
    "fb": HTTPMediaType(type: "application", subType: "x-maker"),
    "book": HTTPMediaType(type: "application", subType: "x-maker"),
    "fbdoc": HTTPMediaType(type: "application", subType: "x-maker"),
    "md5": HTTPMediaType(type: "application", subType: "x-md5"),
    "mif": HTTPMediaType(type: "application", subType: "x-mif"),
    "m3u8": HTTPMediaType(type: "application", subType: "x-mpegURL"),
    "wmd": HTTPMediaType(type: "application", subType: "x-ms-wmd"),
    "wmz": HTTPMediaType(type: "application", subType: "x-ms-wmz"),
    "com": HTTPMediaType(type: "application", subType: "x-msdos-program"),
    "exe": HTTPMediaType(type: "application", subType: "x-msdos-program"),
    "bat": HTTPMediaType(type: "application", subType: "x-msdos-program"),
    "dll": HTTPMediaType(type: "application", subType: "x-msdos-program"),
    "msi": HTTPMediaType(type: "application", subType: "x-msi"),
    "nc": HTTPMediaType(type: "application", subType: "x-netcdf"),
    "pac": HTTPMediaType(type: "application", subType: "x-ns-proxy-autoconfig"),
    "dat": HTTPMediaType(type: "application", subType: "x-ns-proxy-autoconfig"),
    "nwc": HTTPMediaType(type: "application", subType: "x-nwc"),
    "o": HTTPMediaType(type: "application", subType: "x-object"),
    "oza": HTTPMediaType(type: "application", subType: "x-oz-application"),
    "p7r": HTTPMediaType(type: "application", subType: "x-pkcs7-certreqresp"),
    "crl": HTTPMediaType(type: "application", subType: "x-pkcs7-crl"),
    "pyc": HTTPMediaType(type: "application", subType: "x-python-code"),
    "pyo": HTTPMediaType(type: "application", subType: "x-python-code"),
    "qgs": HTTPMediaType(type: "application", subType: "x-qgis"),
    "shp": HTTPMediaType(type: "application", subType: "x-qgis"),
    "shx": HTTPMediaType(type: "application", subType: "x-qgis"),
    "qtl": HTTPMediaType(type: "application", subType: "x-quicktimeplayer"),
    "rdp": HTTPMediaType(type: "application", subType: "x-rdp"),
    "rpm": HTTPMediaType(type: "application", subType: "x-redhat-package-manager"),
    "rss": HTTPMediaType(type: "application", subType: "x-rss+xml"),
    "rb": HTTPMediaType(type: "application", subType: "x-ruby"),
    "sci": HTTPMediaType(type: "application", subType: "x-scilab"),
    "sce": HTTPMediaType(type: "application", subType: "x-scilab"),
    "xcos": HTTPMediaType(type: "application", subType: "x-scilab-xcos"),
    "sh": HTTPMediaType(type: "application", subType: "x-sh"),
    "sha1": HTTPMediaType(type: "application", subType: "x-sha1"),
    "shar": HTTPMediaType(type: "application", subType: "x-shar"),
    "swf": HTTPMediaType(type: "application", subType: "x-shockwave-flash"),
    "swfl": HTTPMediaType(type: "application", subType: "x-shockwave-flash"),
    "scr": HTTPMediaType(type: "application", subType: "x-silverlight"),
    "sql": HTTPMediaType(type: "application", subType: "x-sql"),
    "sit": HTTPMediaType(type: "application", subType: "x-stuffit"),
    "sitx": HTTPMediaType(type: "application", subType: "x-stuffit"),
    "sv4cpio": HTTPMediaType(type: "application", subType: "x-sv4cpio"),
    "sv4crc": HTTPMediaType(type: "application", subType: "x-sv4crc"),
    "tar": HTTPMediaType(type: "application", subType: "x-tar"),
    "tcl": HTTPMediaType(type: "application", subType: "x-tcl"),
    "gf": HTTPMediaType(type: "application", subType: "x-tex-gf"),
    "pk": HTTPMediaType(type: "application", subType: "x-tex-pk"),
    "texinfo": HTTPMediaType(type: "application", subType: "x-texinfo"),
    "texi": HTTPMediaType(type: "application", subType: "x-texinfo"),
    "~": HTTPMediaType(type: "application", subType: "x-trash"),
    "%": HTTPMediaType(type: "application", subType: "x-trash"),
    "bak": HTTPMediaType(type: "application", subType: "x-trash"),
    "old": HTTPMediaType(type: "application", subType: "x-trash"),
    "sik": HTTPMediaType(type: "application", subType: "x-trash"),
    "t": HTTPMediaType(type: "application", subType: "x-troff"),
    "tr": HTTPMediaType(type: "application", subType: "x-troff"),
    "roff": HTTPMediaType(type: "application", subType: "x-troff"),
    "man": HTTPMediaType(type: "application", subType: "x-troff-man"),
    "me": HTTPMediaType(type: "application", subType: "x-troff-me"),
    "ms": HTTPMediaType(type: "application", subType: "x-troff-ms"),
    "ustar": HTTPMediaType(type: "application", subType: "x-ustar"),
    "src": HTTPMediaType(type: "application", subType: "x-wais-source"),
    "wz": HTTPMediaType(type: "application", subType: "x-wingz"),
    "crt": HTTPMediaType(type: "application", subType: "x-x509-ca-cert"),
    "xcf": HTTPMediaType(type: "application", subType: "x-xcf"),
    "fig": HTTPMediaType(type: "application", subType: "x-xfig"),
    "xpi": HTTPMediaType(type: "application", subType: "x-xpinstall"),
    "amr": HTTPMediaType(type: "audio", subType: "amr"),
    "awb": HTTPMediaType(type: "audio", subType: "amr-wb"),
    "axa": HTTPMediaType(type: "audio", subType: "annodex"),
    "au": HTTPMediaType(type: "audio", subType: "basic"),
    "snd": HTTPMediaType(type: "audio", subType: "basic"),
    "csd": HTTPMediaType(type: "audio", subType: "csound"),
    "orc": HTTPMediaType(type: "audio", subType: "csound"),
    "sco": HTTPMediaType(type: "audio", subType: "csound"),
    "flac": HTTPMediaType(type: "audio", subType: "flac"),
    "mid": HTTPMediaType(type: "audio", subType: "midi"),
    "midi": HTTPMediaType(type: "audio", subType: "midi"),
    "kar": HTTPMediaType(type: "audio", subType: "midi"),
    "mpga": HTTPMediaType(type: "audio", subType: "mpeg"),
    "mpega": HTTPMediaType(type: "audio", subType: "mpeg"),
    "mp2": HTTPMediaType(type: "audio", subType: "mpeg"),
    "mp3": HTTPMediaType(type: "audio", subType: "mpeg"),
    "m4a": HTTPMediaType(type: "audio", subType: "mpeg"),
    "m3u": HTTPMediaType(type: "audio", subType: "mpegurl"),
    "oga": HTTPMediaType(type: "audio", subType: "ogg"),
    "ogg": HTTPMediaType(type: "audio", subType: "ogg"),
    "opus": HTTPMediaType(type: "audio", subType: "ogg"),
    "spx": HTTPMediaType(type: "audio", subType: "ogg"),
    "sid": HTTPMediaType(type: "audio", subType: "prs.sid"),
    "aif": HTTPMediaType(type: "audio", subType: "x-aiff"),
    "aiff": HTTPMediaType(type: "audio", subType: "x-aiff"),
    "aifc": HTTPMediaType(type: "audio", subType: "x-aiff"),
    "gsm": HTTPMediaType(type: "audio", subType: "x-gsm"),
    "wma": HTTPMediaType(type: "audio", subType: "x-ms-wma"),
    "wax": HTTPMediaType(type: "audio", subType: "x-ms-wax"),
    "ra": HTTPMediaType(type: "audio", subType: "x-pn-realaudio"),
    "rm": HTTPMediaType(type: "audio", subType: "x-pn-realaudio"),
    "ram": HTTPMediaType(type: "audio", subType: "x-pn-realaudio"),
    "pls": HTTPMediaType(type: "audio", subType: "x-scpls"),
    "sd2": HTTPMediaType(type: "audio", subType: "x-sd2"),
    "wav": HTTPMediaType(type: "audio", subType: "x-wav"),
    "alc": HTTPMediaType(type: "chemical", subType: "x-alchemy"),
    "cac": HTTPMediaType(type: "chemical", subType: "x-cache"),
    "cache": HTTPMediaType(type: "chemical", subType: "x-cache"),
    "csf": HTTPMediaType(type: "chemical", subType: "x-cache-csf"),
    "cbin": HTTPMediaType(type: "chemical", subType: "x-cactvs-binary"),
    "cascii": HTTPMediaType(type: "chemical", subType: "x-cactvs-binary"),
    "ctab": HTTPMediaType(type: "chemical", subType: "x-cactvs-binary"),
    "cdx": HTTPMediaType(type: "chemical", subType: "x-cdx"),
    "cer": HTTPMediaType(type: "chemical", subType: "x-cerius"),
    "c3d": HTTPMediaType(type: "chemical", subType: "x-chem3d"),
    "chm": HTTPMediaType(type: "chemical", subType: "x-chemdraw"),
    "cif": HTTPMediaType(type: "chemical", subType: "x-cif"),
    "cmdf": HTTPMediaType(type: "chemical", subType: "x-cmdf"),
    "cml": HTTPMediaType(type: "chemical", subType: "x-cml"),
    "cpa": HTTPMediaType(type: "chemical", subType: "x-compass"),
    "bsd": HTTPMediaType(type: "chemical", subType: "x-crossfire"),
    "csml": HTTPMediaType(type: "chemical", subType: "x-csml"),
    "csm": HTTPMediaType(type: "chemical", subType: "x-csml"),
    "ctx": HTTPMediaType(type: "chemical", subType: "x-ctx"),
    "cxf": HTTPMediaType(type: "chemical", subType: "x-cxf"),
    "cef": HTTPMediaType(type: "chemical", subType: "x-cxf"),
    "emb": HTTPMediaType(type: "chemical", subType: "x-embl-dl-nucleotide"),
    "embl": HTTPMediaType(type: "chemical", subType: "x-embl-dl-nucleotide"),
    "spc": HTTPMediaType(type: "chemical", subType: "x-galactic-spc"),
    "inp": HTTPMediaType(type: "chemical", subType: "x-gamess-input"),
    "gam": HTTPMediaType(type: "chemical", subType: "x-gamess-input"),
    "gamin": HTTPMediaType(type: "chemical", subType: "x-gamess-input"),
    "fch": HTTPMediaType(type: "chemical", subType: "x-gaussian-checkpoint"),
    "fchk": HTTPMediaType(type: "chemical", subType: "x-gaussian-checkpoint"),
    "cub": HTTPMediaType(type: "chemical", subType: "x-gaussian-cube"),
    "gau": HTTPMediaType(type: "chemical", subType: "x-gaussian-input"),
    "gjc": HTTPMediaType(type: "chemical", subType: "x-gaussian-input"),
    "gjf": HTTPMediaType(type: "chemical", subType: "x-gaussian-input"),
    "gal": HTTPMediaType(type: "chemical", subType: "x-gaussian-log"),
    "gcg": HTTPMediaType(type: "chemical", subType: "x-gcg8-sequence"),
    "gen": HTTPMediaType(type: "chemical", subType: "x-genbank"),
    "hin": HTTPMediaType(type: "chemical", subType: "x-hin"),
    "istr": HTTPMediaType(type: "chemical", subType: "x-isostar"),
    "ist": HTTPMediaType(type: "chemical", subType: "x-isostar"),
    "jdx": HTTPMediaType(type: "chemical", subType: "x-jcamp-dx"),
    "dx": HTTPMediaType(type: "chemical", subType: "x-jcamp-dx"),
    "kin": HTTPMediaType(type: "chemical", subType: "x-kinemage"),
    "mcm": HTTPMediaType(type: "chemical", subType: "x-macmolecule"),
    "mmd": HTTPMediaType(type: "chemical", subType: "x-macromodel-input"),
    "mmod": HTTPMediaType(type: "chemical", subType: "x-macromodel-input"),
    "mol": HTTPMediaType(type: "chemical", subType: "x-mdl-molfile"),
    "rd": HTTPMediaType(type: "chemical", subType: "x-mdl-rdfile"),
    "rxn": HTTPMediaType(type: "chemical", subType: "x-mdl-rxnfile"),
    "sd": HTTPMediaType(type: "chemical", subType: "x-mdl-sdfile"),
    "tgf": HTTPMediaType(type: "chemical", subType: "x-mdl-tgf"),
    "mcif": HTTPMediaType(type: "chemical", subType: "x-mmcif"),
    "mol2": HTTPMediaType(type: "chemical", subType: "x-mol2"),
    "b": HTTPMediaType(type: "chemical", subType: "x-molconn-Z"),
    "gpt": HTTPMediaType(type: "chemical", subType: "x-mopac-graph"),
    "mop": HTTPMediaType(type: "chemical", subType: "x-mopac-input"),
    "mopcrt": HTTPMediaType(type: "chemical", subType: "x-mopac-input"),
    "mpc": HTTPMediaType(type: "chemical", subType: "x-mopac-input"),
    "zmt": HTTPMediaType(type: "chemical", subType: "x-mopac-input"),
    "moo": HTTPMediaType(type: "chemical", subType: "x-mopac-out"),
    "mvb": HTTPMediaType(type: "chemical", subType: "x-mopac-vib"),
    "asn": HTTPMediaType(type: "chemical", subType: "x-ncbi-asn1"),
    "prt": HTTPMediaType(type: "chemical", subType: "x-ncbi-asn1-ascii"),
    "ent": HTTPMediaType(type: "chemical", subType: "x-ncbi-asn1-ascii"),
    "val": HTTPMediaType(type: "chemical", subType: "x-ncbi-asn1-binary"),
    "aso": HTTPMediaType(type: "chemical", subType: "x-ncbi-asn1-binary"),
    "pdb": HTTPMediaType(type: "chemical", subType: "x-pdb"),
    "ros": HTTPMediaType(type: "chemical", subType: "x-rosdal"),
    "sw": HTTPMediaType(type: "chemical", subType: "x-swissprot"),
    "vms": HTTPMediaType(type: "chemical", subType: "x-vamas-iso14976"),
    "vmd": HTTPMediaType(type: "chemical", subType: "x-vmd"),
    "xtel": HTTPMediaType(type: "chemical", subType: "x-xtel"),
    "xyz": HTTPMediaType(type: "chemical", subType: "x-xyz"),
    "gif": HTTPMediaType(type: "image", subType: "gif"),
    "ief": HTTPMediaType(type: "image", subType: "ief"),
    "jp2": HTTPMediaType(type: "image", subType: "jp2"),
    "jpg2": HTTPMediaType(type: "image", subType: "jp2"),
    "jpeg": HTTPMediaType(type: "image", subType: "jpeg"),
    "jpg": HTTPMediaType(type: "image", subType: "jpeg"),
    "jpe": HTTPMediaType(type: "image", subType: "jpeg"),
    "jpm": HTTPMediaType(type: "image", subType: "jpm"),
    "jpx": HTTPMediaType(type: "image", subType: "jpx"),
    "jpf": HTTPMediaType(type: "image", subType: "jpx"),
    "pcx": HTTPMediaType(type: "image", subType: "pcx"),
    "png": HTTPMediaType(type: "image", subType: "png"),
    "svg": HTTPMediaType(type: "image", subType: "svg+xml"),
    "svgz": HTTPMediaType(type: "image", subType: "svg+xml"),
    "tiff": HTTPMediaType(type: "image", subType: "tiff"),
    "tif": HTTPMediaType(type: "image", subType: "tiff"),
    "djvu": HTTPMediaType(type: "image", subType: "vnd.djvu"),
    "djv": HTTPMediaType(type: "image", subType: "vnd.djvu"),
    "ico": HTTPMediaType(type: "image", subType: "vnd.microsoft.icon"),
    "wbmp": HTTPMediaType(type: "image", subType: "vnd.wap.wbmp"),
    "cr2": HTTPMediaType(type: "image", subType: "x-canon-cr2"),
    "crw": HTTPMediaType(type: "image", subType: "x-canon-crw"),
    "ras": HTTPMediaType(type: "image", subType: "x-cmu-raster"),
    "cdr": HTTPMediaType(type: "image", subType: "x-coreldraw"),
    "pat": HTTPMediaType(type: "image", subType: "x-coreldrawpattern"),
    "cdt": HTTPMediaType(type: "image", subType: "x-coreldrawtemplate"),
    "erf": HTTPMediaType(type: "image", subType: "x-epson-erf"),
    "art": HTTPMediaType(type: "image", subType: "x-jg"),
    "jng": HTTPMediaType(type: "image", subType: "x-jng"),
    "bmp": HTTPMediaType(type: "image", subType: "x-ms-bmp"),
    "nef": HTTPMediaType(type: "image", subType: "x-nikon-nef"),
    "orf": HTTPMediaType(type: "image", subType: "x-olympus-orf"),
    "psd": HTTPMediaType(type: "image", subType: "x-photoshop"),
    "pnm": HTTPMediaType(type: "image", subType: "x-portable-anymap"),
    "pbm": HTTPMediaType(type: "image", subType: "x-portable-bitmap"),
    "pgm": HTTPMediaType(type: "image", subType: "x-portable-graymap"),
    "ppm": HTTPMediaType(type: "image", subType: "x-portable-pixmap"),
    "rgb": HTTPMediaType(type: "image", subType: "x-rgb"),
    "xbm": HTTPMediaType(type: "image", subType: "x-xbitmap"),
    "xpm": HTTPMediaType(type: "image", subType: "x-xpixmap"),
    "xwd": HTTPMediaType(type: "image", subType: "x-xwindowdump"),
    "eml": HTTPMediaType(type: "message", subType: "rfc822"),
    "igs": HTTPMediaType(type: "model", subType: "iges"),
    "iges": HTTPMediaType(type: "model", subType: "iges"),
    "msh": HTTPMediaType(type: "model", subType: "mesh"),
    "mesh": HTTPMediaType(type: "model", subType: "mesh"),
    "silo": HTTPMediaType(type: "model", subType: "mesh"),
    "wrl": HTTPMediaType(type: "model", subType: "vrml"),
    "vrml": HTTPMediaType(type: "model", subType: "vrml"),
    "x3dv": HTTPMediaType(type: "model", subType: "x3d+vrml"),
    "x3d": HTTPMediaType(type: "model", subType: "x3d+xml"),
    "x3db": HTTPMediaType(type: "model", subType: "x3d+binary"),
    "appcache": HTTPMediaType(type: "text", subType: "cache-manifest"),
    "ics": HTTPMediaType(type: "text", subType: "calendar"),
    "icz": HTTPMediaType(type: "text", subType: "calendar"),
    "css": HTTPMediaType(type: "text", subType: "css"),
    "csv": HTTPMediaType(type: "text", subType: "csv"),
    "323": HTTPMediaType(type: "text", subType: "h323"),
    "html": HTTPMediaType(type: "text", subType: "html"),
    "htm": HTTPMediaType(type: "text", subType: "html"),
    "shtml": HTTPMediaType(type: "text", subType: "html"),
    "uls": HTTPMediaType(type: "text", subType: "iuls"),
    "mml": HTTPMediaType(type: "text", subType: "mathml"),
    "asc": HTTPMediaType(type: "text", subType: "plain"),
    "txt": HTTPMediaType(type: "text", subType: "plain"),
    "text": HTTPMediaType(type: "text", subType: "plain"),
    "pot": HTTPMediaType(type: "text", subType: "plain"),
    "brf": HTTPMediaType(type: "text", subType: "plain"),
    "srt": HTTPMediaType(type: "text", subType: "plain"),
    "rtx": HTTPMediaType(type: "text", subType: "richtext"),
    "sct": HTTPMediaType(type: "text", subType: "scriptlet"),
    "wsc": HTTPMediaType(type: "text", subType: "scriptlet"),
    "tm": HTTPMediaType(type: "text", subType: "texmacs"),
    "tsv": HTTPMediaType(type: "text", subType: "tab-separated-values"),
    "ttl": HTTPMediaType(type: "text", subType: "turtle"),
    "jad": HTTPMediaType(type: "text", subType: "vnd.sun.j2me.app-descriptor"),
    "wml": HTTPMediaType(type: "text", subType: "vnd.wap.wml"),
    "wmls": HTTPMediaType(type: "text", subType: "vnd.wap.wmlscript"),
    "bib": HTTPMediaType(type: "text", subType: "x-bibtex"),
    "boo": HTTPMediaType(type: "text", subType: "x-boo"),
    "h++": HTTPMediaType(type: "text", subType: "x-c++hdr"),
    "hpp": HTTPMediaType(type: "text", subType: "x-c++hdr"),
    "hxx": HTTPMediaType(type: "text", subType: "x-c++hdr"),
    "hh": HTTPMediaType(type: "text", subType: "x-c++hdr"),
    "c++": HTTPMediaType(type: "text", subType: "x-c++src"),
    "cpp": HTTPMediaType(type: "text", subType: "x-c++src"),
    "cxx": HTTPMediaType(type: "text", subType: "x-c++src"),
    "cc": HTTPMediaType(type: "text", subType: "x-c++src"),
    "h": HTTPMediaType(type: "text", subType: "x-chdr"),
    "htc": HTTPMediaType(type: "text", subType: "x-component"),
    "c": HTTPMediaType(type: "text", subType: "x-csrc"),
    "d": HTTPMediaType(type: "text", subType: "x-dsrc"),
    "diff": HTTPMediaType(type: "text", subType: "x-diff"),
    "patch": HTTPMediaType(type: "text", subType: "x-diff"),
    "hs": HTTPMediaType(type: "text", subType: "x-haskell"),
    "java": HTTPMediaType(type: "text", subType: "x-java"),
    "ly": HTTPMediaType(type: "text", subType: "x-lilypond"),
    "lhs": HTTPMediaType(type: "text", subType: "x-literate-haskell"),
    "moc": HTTPMediaType(type: "text", subType: "x-moc"),
    "p": HTTPMediaType(type: "text", subType: "x-pascal"),
    "pas": HTTPMediaType(type: "text", subType: "x-pascal"),
    "gcd": HTTPMediaType(type: "text", subType: "x-pcs-gcd"),
    "pl": HTTPMediaType(type: "text", subType: "x-perl"),
    "pm": HTTPMediaType(type: "text", subType: "x-perl"),
    "py": HTTPMediaType(type: "text", subType: "x-python"),
    "scala": HTTPMediaType(type: "text", subType: "x-scala"),
    "etx": HTTPMediaType(type: "text", subType: "x-setext"),
    "sfv": HTTPMediaType(type: "text", subType: "x-sfv"),
    "tk": HTTPMediaType(type: "text", subType: "x-tcl"),
    "tex": HTTPMediaType(type: "text", subType: "x-tex"),
    "ltx": HTTPMediaType(type: "text", subType: "x-tex"),
    "sty": HTTPMediaType(type: "text", subType: "x-tex"),
    "cls": HTTPMediaType(type: "text", subType: "x-tex"),
    "vcs": HTTPMediaType(type: "text", subType: "x-vcalendar"),
    "vcf": HTTPMediaType(type: "text", subType: "x-vcard"),
    "3gp": HTTPMediaType(type: "video", subType: "3gpp"),
    "axv": HTTPMediaType(type: "video", subType: "annodex"),
    "dl": HTTPMediaType(type: "video", subType: "dl"),
    "dif": HTTPMediaType(type: "video", subType: "dv"),
    "dv": HTTPMediaType(type: "video", subType: "dv"),
    "fli": HTTPMediaType(type: "video", subType: "fli"),
    "gl": HTTPMediaType(type: "video", subType: "gl"),
    "mpeg": HTTPMediaType(type: "video", subType: "mpeg"),
    "mpg": HTTPMediaType(type: "video", subType: "mpeg"),
    "mpe": HTTPMediaType(type: "video", subType: "mpeg"),
    "ts": HTTPMediaType(type: "video", subType: "MP2T"),
    "mp4": HTTPMediaType(type: "video", subType: "mp4"),
    "qt": HTTPMediaType(type: "video", subType: "quicktime"),
    "mov": HTTPMediaType(type: "video", subType: "quicktime"),
    "ogv": HTTPMediaType(type: "video", subType: "ogg"),
    "webm": HTTPMediaType(type: "video", subType: "webm"),
    "mxu": HTTPMediaType(type: "video", subType: "vnd.mpegurl"),
    "flv": HTTPMediaType(type: "video", subType: "x-flv"),
    "lsf": HTTPMediaType(type: "video", subType: "x-la-asf"),
    "lsx": HTTPMediaType(type: "video", subType: "x-la-asf"),
    "mng": HTTPMediaType(type: "video", subType: "x-mng"),
    "asf": HTTPMediaType(type: "video", subType: "x-ms-asf"),
    "asx": HTTPMediaType(type: "video", subType: "x-ms-asf"),
    "wm": HTTPMediaType(type: "video", subType: "x-ms-wm"),
    "wmv": HTTPMediaType(type: "video", subType: "x-ms-wmv"),
    "wmx": HTTPMediaType(type: "video", subType: "x-ms-wmx"),
    "wvx": HTTPMediaType(type: "video", subType: "x-ms-wvx"),
    "avi": HTTPMediaType(type: "video", subType: "x-msvideo"),
    "movie": HTTPMediaType(type: "video", subType: "x-sgi-movie"),
    "mpv": HTTPMediaType(type: "video", subType: "x-matroska"),
    "mkv": HTTPMediaType(type: "video", subType: "x-matroska"),
    "ice": HTTPMediaType(type: "x-conference", subType: "x-cooltalk"),
    "sisx": HTTPMediaType(type: "x-epoc", subType: "x-sisx-app"),
    "vrm": HTTPMediaType(type: "x-world", subType: "x-vrml"),
]
