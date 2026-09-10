#if canImport(FoundationEssentials)
public import FoundationEssentials
#else
public import Foundation
#endif
public import HTTPTypes

extension JSONEncoder: ContentEncoder {
    public func encode(_ encodable: some Encodable, to body: inout Data, headers: inout HTTPFields, userInfo: [CodingUserInfoKey : any Sendable]) throws {
        headers.contentType = .json

        if !userInfo.isEmpty { // Changing a coder's userInfo is a thread-unsafe mutation, operate on a copy
            #if canImport(Darwin)
            let existingUserInfo = self.userInfo
            #else
            #warning("Check")
            // JSONEncoder.userInfo does not declare its values as Sendable yet on Linux.
            // This appears to be an oversight, as JSONDecoder does not have the same issue.
            let existingUserInfo = self.userInfo as! [CodingUserInfoKey: any Sendable]
            #endif

            try body.append(JSONEncoder.custom(
                dates: self.dateEncodingStrategy,
                data: self.dataEncodingStrategy,
                keys: self.keyEncodingStrategy,
                format: self.outputFormatting,
                floats: self.nonConformingFloatEncodingStrategy,
                userInfo: existingUserInfo.merging(userInfo) { $1 }
            ).encode(encodable))
        } else {
            try body.append(self.encode(encodable))
        }
    }
}

extension JSONDecoder: ContentDecoder {
    public func decode<D>(_ decodable: D.Type, from body: Data, headers: HTTPFields, userInfo: [CodingUserInfoKey : any Sendable]) throws -> D where D : Decodable {
        if !userInfo.isEmpty {
            let actualDecoder = JSONDecoder() // Changing a coder's userInfo is a thread-unsafe mutation, operate on a copy
            actualDecoder.dateDecodingStrategy = self.dateDecodingStrategy
            actualDecoder.dataDecodingStrategy = self.dataDecodingStrategy
            actualDecoder.nonConformingFloatDecodingStrategy = self.nonConformingFloatDecodingStrategy
            actualDecoder.keyDecodingStrategy = self.keyDecodingStrategy
            actualDecoder.allowsJSON5 = self.allowsJSON5
            actualDecoder.assumesTopLevelDictionary = self.assumesTopLevelDictionary
            actualDecoder.userInfo = self.userInfo.merging(userInfo) { $1 }
            return try actualDecoder.decode(D.self, from: body)
        } else {
            return try self.decode(D.self, from: body)
        }
    }
}
