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
    public func parse(data: Data) -> URI {
        // create url results struct
        var url = http_parser_url()
        http_parser_url_init(&url)
        
        // parse url
        data.withUnsafeBytes { pointer in
            _ = http_parser_parse_url(pointer, data.count, 0, &url)
        }

        // fetch offsets from result
        let (scheme, hostname, port, path, query, fragment, userinfo) = url.field_data

        // parse uri info
        let info: URI.UserInfo?
        if userinfo.len > 0, userinfo.len > 0 {
            let bytes = data[numericCast(userinfo.off) ..< numericCast(userinfo.off + userinfo.len)]
            
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
        if let bytes = data.string(for: port) {
            p = Port(bytes)
        } else {
            p = nil
        }

        // create uri
        let uri = URI(
            scheme: data.string(for: scheme),
            userInfo: info,
            hostname: data.string(for: hostname),
            port: p,
            pathData: data.data(for: path),
            query: data.string(for: query),
            fragment: data.string(for: fragment)
        )
        return uri
    }
}

// MARK: Utilities

extension Data {
    fileprivate func data(for field: http_parser_url_field_data) -> Data {
        return self[numericCast(field.off)..<numericCast(field.off + field.len)]
    }
    
    /// Creates a string from the supplied field data offsets
    fileprivate func string(for field: http_parser_url_field_data) -> String? {
        let data = self.data(for: field)
        
        guard data.count > 0 else {
            return nil
        }
        
        return String(data: data, encoding: .utf8)
    }
}

