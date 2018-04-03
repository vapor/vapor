@available(*, deprecated, renamed: "HTTPBodyEncoder")
public typealias BodyEncoder = HTTPBodyEncoder
@available(*, deprecated, renamed: "HTTPBodyDecoder")
public typealias BodyDecoder = HTTPBodyDecoder


extension ContentCoders {
    @available(*, deprecated, renamed: "requireBodyEncoder(for:)")
    public func requireEncoder(for mediaType: MediaType) throws -> HTTPBodyEncoder {
        return try requireBodyEncoder(for: mediaType)
    }

    @available(*, deprecated, renamed: "requireBodyDecoder(for:)")
    public func requireDecoder(for mediaType: MediaType) throws -> HTTPBodyDecoder {
        return try requireBodyDecoder(for: mediaType)
    }
}

import Crypto

@available(*, deprecated, renamed: "BCryptDigest")
public typealias BCryptHasher = BCryptDigest
