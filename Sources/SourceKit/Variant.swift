import CSourceKit

enum Variant {
    case array([Variant])
    case dictionary([String: Variant])
    case string(String)
    case integer(Int)
    case bool(Bool)

    init?(_ raw: sourcekitd_variant_t) {
        let type = sourcekitd_variant_get_type(raw)
        let variant: Variant

        switch type {
        case SOURCEKITD_VARIANT_TYPE_ARRAY:
            var array: [Variant] = []
            _ = withUnsafeMutablePointer(to: &array) { arrayPtr in
                sourcekitd_variant_array_apply_f(raw, { index, value, context in
                    if let value = Variant(value), let context = context {
                        let localArray = context.assumingMemoryBound(to: [Variant].self)
                        localArray.pointee.insert(value, at: Int(index))
                    }
                    return true
                }, arrayPtr)
            }
            variant = .array(array)
        case SOURCEKITD_VARIANT_TYPE_DICTIONARY:
            var dict: [String: Variant] = [:]
            _ = withUnsafeMutablePointer(to: &dict) { dictPtr in
                sourcekitd_variant_dictionary_apply_f(raw, { key, value, context in

                    if
                        let key = String(sourceKitUID: key!),
                        let value = Variant(value),
                        let context = context
                    {
                        let localDict = context.assumingMemoryBound(to: [String: Variant].self)
                        localDict.pointee[key] = value
                    }
                    return true
                }, dictPtr)
            }
            variant = .dictionary(dict)
        case SOURCEKITD_VARIANT_TYPE_STRING:
            let string = String(
                bytes: sourcekitd_variant_string_get_ptr(raw),
                length: sourcekitd_variant_string_get_length(raw)
            )
            variant = .string(string!)
        case SOURCEKITD_VARIANT_TYPE_INT64:
            variant = .integer(Int(sourcekitd_variant_int64_get_value(raw)))
        case SOURCEKITD_VARIANT_TYPE_BOOL:
            variant = .bool(sourcekitd_variant_bool_get_value(raw))
        case SOURCEKITD_VARIANT_TYPE_UID:
            variant = .string(String(sourceKitUID: sourcekitd_variant_uid_get_value(raw))!)
        default:
            return nil
        }

        self = variant
    }

    var dictionary: [String: Variant]? {
        switch self {
        case .dictionary(let dict):
            return dict
        default:
            return nil
        }
    }

    var array: [Variant]? {
        switch self {
        case .array(let array):
            return array
        default:
            return nil
        }
    }

    var string: String? {
        switch self {
        case .string(let string):
            return string
        default:
            return nil
        }
    }

    var integer: Int? {
        switch self {
        case .integer(let int):
            return int
        default:
            return nil
        }
    }

    func parseSyntaxMap() -> [Syntax]? {
        guard let mapped = dictionary?["key.syntaxmap"]?.array?.flatMap({ variant in
            return variant.parseSyntax()
        }) else {
            return nil
        }

        return mapped
    }

    func parseSyntax() -> Syntax? {
        guard let dict = dictionary else {
            return nil
        }

        guard let kind = dict["key.kind"]?.string else {
            return nil
        }

        guard let offset = dict["key.offset"]?.integer else {
            return nil
        }

        guard let length = dict["key.length"]?.integer else {
            return nil
        }

        return Syntax(kind: kind, offset: offset, length: length)
    }

    func parseSubStructures(_ syntaxMap: SyntaxMap) -> [Structure]? {
        guard let mapped = dictionary?["key.substructure"]?.array?.flatMap({ variant in
            return variant.parseStructure(syntaxMap)
        }) else {
            return nil
        }
        return mapped
    }

    func parseStructure(_ syntaxMap: SyntaxMap) -> Structure? {
        guard let dict = dictionary else {
            return nil
        }

        guard let kindString = dict["key.kind"]?.string else {
            return nil
        }

        let kind: StructureKind
        switch kindString {
        case "source.lang.swift.decl.class":
            kind = .`class`
        case "source.lang.swift.decl.struct":
            kind = .`struct`
        case "source.lang.swift.decl.var.instance", "source.lang.swift.decl.var.static":
            guard let typeName = dict["key.typename"]?.string else {
                return nil
            }
            kind = .`var`(typeName: typeName, isInstance: kindString.hasSuffix("instance"))
        case "source.lang.swift.decl.function.method.instance", "source.lang.swift.decl.function.method.static":
            kind = .method(isInstance: kindString.hasSuffix("instance"))
        case "source.lang.swift.decl.extension":
            kind = .`extension`
        default:
            print("Unsupported kind: \(kindString)")
            return nil
        }


        guard let name = dict["key.name"]?.string else {
            return nil
        }



        guard let offset = dict["key.offset"]?.integer else {
            return nil
        }

        let inheritedTypes = dict["key.inheritedtypes"]?.array?.flatMap({ variant in
            variant.dictionary?["key.name"]?.string
        }) ?? []

        let sub = parseSubStructures(syntaxMap) ?? []

        let comments = syntaxMap.comments(beforeOffset: offset)
        return Structure(
            name: name,
            kind: kind,
            subStructures: sub,
            accessibility: .`internal`,
            inheritedTypes: inheritedTypes,
            comments: comments
        )
    }

    func formatted(level: Int = 0) -> String {
        let indent = String(repeating: "    ", count: level)
        switch self {
        case .array(let array):
            return array.map({ v in
                return "\n" + indent + v.formatted(level: level + 1)
            }).joined(separator: "") + "\n"
        case .dictionary(let dict):
            var string = ""

            for (key, val) in dict {
                string += "\n" + indent + key + ": " + val.formatted(level: level + 1)
            }

            return string
        case .integer(let int):
            return int.description
        case .string(let string):
            return string
        case .bool(let bool):
            return bool ? "true" : "false"
        }
    }
}

extension String {
    /**
     Cache SourceKit requests for strings from UIDs
     - returns: Cached UID string if available, nil otherwise.
     */
    init?(sourceKitUID: sourcekitd_uid_t) {
        let length = sourcekitd_uid_get_length(sourceKitUID)
        let bytes = sourcekitd_uid_get_string_ptr(sourceKitUID)
        if let uidString = String(bytes: bytes!, length: length) {
            /*
             `String` created by `String(UTF8String:)` is based on `NSString`.
             `NSString` base `String` has performance penalty on getting `hashValue`.
             Everytime on getting `hashValue`, it calls `decomposedStringWithCanonicalMapping` for
             "Unicode Normalization Form D" and creates autoreleased `CFString (mutable)` and
             `CFString (store)`. Those `CFString` are created every time on using `hashValue`, such as
             using `String` for Dictionary's key or adding to Set.
             For avoiding those penalty, replaces with enum's rawValue String if defined in SourceKitten.
             That does not cause calling `decomposedStringWithCanonicalMapping`.
             */

            self = uidString
            return
        }
        return nil
    }

    init?(bytes: UnsafePointer<Int8>, length: Int) {
        let pointer = UnsafeMutablePointer<Int8>(mutating: bytes)
        // It seems SourceKitService returns string in other than NSUTF8StringEncoding.
        // We'll try another encodings if fail.
        for encoding in [String.Encoding.utf8, .nextstep, .ascii] {
            if let string = String(bytesNoCopy: pointer, length: length, encoding: encoding,
                                   freeWhenDone: false) {
                self = "\(string)"
                return
            }
        }
        return nil
    }
}
