import Bits
import CSourceKit
import Foundation

public struct File {
    public let syntaxMap: SyntaxMap
    public let structures: [Structure]

    init(_ contents: Data) throws {
        guard let string = String(data: contents, encoding: .utf8) else {
            throw "could not convert data to string"
        }

        let dict: [sourcekitd_uid_t: sourcekitd_object_t?] = [
            sourcekitd_uid_get_from_cstr("key.request"): sourcekitd_request_uid_create(sourcekitd_uid_get_from_cstr("source.request.editor.open")),
            sourcekitd_uid_get_from_cstr("key.name"): sourcekitd_request_string_create(String(string.hash)),
            sourcekitd_uid_get_from_cstr("key.sourcetext"): sourcekitd_request_string_create(string),
        ]

        var keys = Array(dict.keys.map({ $0 as sourcekitd_uid_t? }))
        var values = Array(dict.values)
        let req = sourcekitd_request_dictionary_create(&keys, &values, dict.count)

        let response = sourcekitd_send_request_sync(req!)
        defer {
            sourcekitd_response_dispose(response!)
        }

        let value = sourcekitd_response_get_value(response!)
        let variant = Variant(value)!

        // print(variant.formatted())

        let syntax = variant.parseSyntaxMap() ?? []
        let syntaxMap = SyntaxMap(contents, syntax)
        structures = variant.parseSubStructures(syntaxMap) ?? []
        self.syntaxMap = syntaxMap
    }
}
