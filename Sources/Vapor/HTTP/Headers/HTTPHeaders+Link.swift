import NIOHTTP1

extension HTTPHeaders {
    /// Convenience for accessing the Link header as an array of provided links.
    ///
    /// See https://datatracker.ietf.org/doc/html/rfc8288
    public var links: [Link]? {
        get {
            self.parseDirectives(name: .link).compactMap(Link.init(directives:))
        }
        set {
            if let header = newValue {
                // N.B.: The sort here is not necessary for protocol reasons; it just hugely simplifies unit tests.
                self.serializeDirectives(header.map(\.directives), name: .link)
            } else {
                self.remove(name: .link)
            }
        }
    }
    
    // TODO: Support multiple relations in a single `rel` attribute, as permitted by spec.
    public struct Link {
        /// See https://www.iana.org/assignments/link-relations/link-relations.xhtml
        public struct Relation: RawRepresentable, Hashable {
            public static let about = Relation("about")
            public static let alternate = Relation("alternate")
            public static let appendix = Relation("appendix")
            public static let archives = Relation("archives")
            public static let author = Relation("author")
            public static let blockedBy = Relation("blockedBy")
            public static let bookmark = Relation("bookmark")
            public static let canonical = Relation("canonical")
            public static let chapter = Relation("chapter")
            public static let citeAs = Relation("cite-as")
            public static let collection = Relation("collection")
            public static let contents = Relation("contents")
            public static let copyright = Relation("copyright")
            public static let current = Relation("current")
            public static let describedBy = Relation("describedby")
            public static let describes = Relation("describes")
            public static let disclosure = Relation("disclosure")
            public static let duplicate = Relation("duplicate")
            public static let edit = Relation("edit")
            public static let editForm = Relation("edit-form")
            public static let editMedia = Relation("edit-media")
            public static let enclosure = Relation("enclosure")
            public static let external = Relation("external")
            public static let first = Relation("first")
            public static let glossary = Relation("glossary")
            public static let help = Relation("help")
            public static let icon = Relation("icon")
            public static let index = Relation("index")
            public static let item = Relation("item")
            public static let last = Relation("last")
            public static let latestVersion = Relation("latest-version")
            public static let license = Relation("license")
            public static let next = Relation("next")
            public static let noFollow = Relation("nofollow")
            public static let noOpener = Relation("noopener")
            public static let noReferer = Relation("noreferer")
            public static let opener = Relation("opener")
            public static let p3pv1 = Relation("P3Pv1")
            public static let prev = Relation("prev")
            public static let preview = Relation("preview")
            public static let previous = Relation("prev") // not a typo; `previous` is a synonym of `prev`
            public static let privacyPolicy = Relation("privacy-policy")
            public static let related = Relation("related")
            public static let section = Relation("section")
            public static let `self` = Relation("self")
            public static let service = Relation("service")
            public static let start = Relation("start")
            public static let status = Relation("status")
            public static let stylesheet = Relation("stylesheet")
            public static let subsection = Relation("subsection")
            public static let tag = Relation("tag")
            public static let termsOfService = Relation("terms-of-service")
            public static let type = Relation("type")
            public static let up = Relation("up")
            public static let via = Relation("via")
            
            public let rawValue: String
            
            public init<S: StringProtocol>(_ rel: S) {
                self.rawValue = String(rel)
            }
            
            public init?(rawValue: String) {
                self.init(rawValue)
            }
        }
        
        public var uri: String
        public var relation: Relation
        public var attributes: [String: String]
        
        public init(uri: String, relation: Relation, attributes: [String: String]) {
            self.uri = uri
            self.relation = relation
            self.attributes = attributes
        }
        
        init?(directives: [Directive]) {
            guard let uriDirective = directives.first, uriDirective.parameter == nil,
                  uriDirective.value.hasPrefix("<"), uriDirective.value.hasSuffix(">"),
                  directives.dropFirst().allSatisfy({ $0.parameter != nil }),
                  let relDirective = directives.first(where: { $0.value == "rel" })
            else {
                return nil
            }
            let remainingDirectives = directives.dropFirst().filter { $0.value != "rel" }
            
            self.init(
                uri: String(uriDirective.value.dropFirst().dropLast()),
                relation: .init(relDirective.parameter!),
                attributes: .init(remainingDirectives.map { (String($0.value), String($0.parameter!)) }) { a, _ in a }
            )
        }
        
        var directives: [Directive] {
            return [
                .init(value: "<\(self.uri)>", parameter: nil),
                .init(value: "rel", parameter: self.relation.rawValue)
            ] + self.attributes.map { .init(value: $0, parameter: $1) }
        }
    }
}
