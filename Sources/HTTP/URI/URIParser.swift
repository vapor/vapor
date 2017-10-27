import Bits
import CHTTP
import Dispatch
import Foundation

// MARK: URI

/// Parses URIs from bytes.
public final class URIParser {
    /// Use a shared parser since URI parser doesn't
    /// require special configuration
    public static let shared = URIParser()

    /// Creates a new URI parser.
    public init() {}

    /// Parses a URI from the supplied bytes.
    public func parse(bytes: Data) -> URI {
        // create url results struct
        var url = http_parser_url()
        http_parser_url_init(&url)
        
        // parse url
        bytes.withUnsafeBytes { pointer in
            _ = http_parser_parse_url(pointer, bytes.count, 0, &url)
        }

        // fetch offsets from result
        let (scheme, hostname, port, path, query, fragment, userinfo) = url.field_data

        // parse uri info
        let info: URI.UserInfo?
        if userinfo.len > 0, userinfo.len > 0 {
            let bytes = bytes[numericCast(userinfo.off) ..< numericCast(userinfo.off + userinfo.len)]
            
            let parts = bytes.split(
                separator: 58,
                maxSplits: 1,
                omittingEmptySubsequences: false
            )
            
            switch parts.count {
            case 2:
                info = URI.UserInfo(
                    username: String(bytes: parts[0], encoding: .utf8) ?? "",
                    info: String(bytes: parts[1], encoding: .utf8)
                )
            case 1:
                info = URI.UserInfo(username: String(bytes: parts[0], encoding: .utf8) ?? "")
            default:
                info = nil
            }
        } else {
            info = nil
        }

        // sets a port if one was supplied
        // in the url bytes
        let p: Port?
        if let bytes = bytes.string(for: port) {
            p = Port(bytes)
        } else {
            p = nil
        }

        // create uri
        let uri = URI(
            scheme: bytes.string(for: scheme) ?? "",
            userInfo: info,
            hostname: bytes.string(for: hostname) ?? "",
            port: p,
            path: bytes.string(for: path) ?? "",
            query: bytes.string(for: query),
            fragment: bytes.string(for: fragment)
        )
        return uri
    }
}

// MARK: Utilities

extension Data {
    /// Creates a string from the supplied field data offsets
    fileprivate func string(for data: http_parser_url_field_data) -> String? {
        guard data.len > 0 else {
            return nil
        }
        
        let alloc = MutableBytesPointer.allocate(capacity: numericCast(data.len))
        
        self.withUnsafeBytes { (pointer: BytesPointer) in
            alloc.initialize(from: pointer, count: numericCast(data.len))
        }
        
        guard let string = String.init(bytesNoCopy: alloc, length: numericCast(data.len), encoding: .utf8, freeWhenDone: true) else {
            alloc.deallocate(capacity: numericCast(data.len))
            return nil
        }
        
        return string
    }
}

