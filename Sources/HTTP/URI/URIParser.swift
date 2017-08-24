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
    public func parse(bytes: DispatchData) -> URI {
        // create url results struct
        var url = http_parser_url()
        http_parser_url_init(&url)

        let copiedData = Data(bytes)

        // parse url
        http_parser_parse_url(copiedData.withUnsafeBytes { $0 }, copiedData.count, 0, &url)

        // fetch offsets from result
        let (scheme, hostname, port, path, query, fragment, userinfo) = url.field_data

        // parse uri info
        let info: URI.UserInfo?
        if userinfo.len > 0, let bytes = copiedData.bytes(for: userinfo) {
            let parts = bytes.split(
                separator: 58,
                maxSplits: 1,
                omittingEmptySubsequences: false
            )
            switch parts.count {
            case 2:
                info = URI.UserInfo(
                    username: String(data: Data(parts[0]), encoding: .utf8) ?? "",
                    info: String(data: Data(parts[1]), encoding: .utf8)
                )
            case 1:
                info = URI.UserInfo(username: String(data: Data(parts[0]), encoding: .utf8) ?? "")
            default:
                info = nil
            }
        } else {
            info = nil
        }

        // sets a port if one was supplied
        // in the url bytes
        let p: Port?
        if let bytes = copiedData.string(for: port) {
            p = Port(bytes)
        } else {
            p = nil
        }

        // create uri
        let uri = URI(
            scheme: copiedData.string(for: scheme) ?? "",
            userInfo: info,
            hostname: copiedData.string(for: hostname) ?? "",
            port: p,
            path: copiedData.string(for: path) ?? "",
            query: copiedData.string(for: query),
            fragment: copiedData.string(for: fragment)
        )
        return uri
    }
}

// MARK: Utilities

extension Data {
    /// Creates a string from the supplied field data offsets
    fileprivate func string(for data: http_parser_url_field_data) -> String? {
        guard let data = bytes(for: data) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// Creates bytes from the supplied field data offset.
    fileprivate func bytes(for data: http_parser_url_field_data) -> Data? {
        return bytes(from: data.off, length: data.len)
    }

    /// Creates bytes from the supplied offset and length
    fileprivate func bytes(from: UInt16, length: UInt16) -> Data? {
        return bytes(from: Int(from), length: Int(length))
    }

    /// Creates bytes from the supplied offset and length
    fileprivate func bytes(from: Int, length: Int) -> Data? {
        guard length > 0 else {
            return nil
        }
        return self[from..<(from+length)]
    }
}

