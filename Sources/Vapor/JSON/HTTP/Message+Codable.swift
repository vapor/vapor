import HTTP
import Foundation

#if swift(>=4.0)
public extension HTTP.Message {
    public func encodeJSONBody<T: Encodable>(_ body: T, using encoder: JSONEncoder = JSONEncoder()) throws {
        let data = try encoder.encode(body)

        // Clear out fields set by Message+JSON extensions
        json = nil

        self.body = Body.data(data.makeBytes())
        headers[.contentType] = "application/json; charset=utf-8"
    }

    public func decodeJSONBody<T: Decodable>(_ type: T.Type = T.self, using decoder: JSONDecoder = JSONDecoder()) throws -> T {
        return try decoder.decode(type, from: Data(bytes: body.bytes ?? []))
    }
}
#endif
