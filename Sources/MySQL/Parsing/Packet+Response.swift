import Foundation

extension Packet {
    /// Returns `true` if this could be a text-protocol response
    var isTextProtocolResponse: Bool {
        return payload.count > 0 && (payload[0] == 0xff || payload[0] == 0xfe || payload[0] == 0x00)
    }
    
    /// Parses this packet into a TextProtocol Response
    func parseResponse(mysql41: Bool) throws -> Response {
        guard self.payload.count > 0 else {
            throw MySQLError(.invalidResponse)
        }
        
        switch self.payload[0] {
        case 0xff:
            // The server sent an error
            guard self.payload.count > 3 else {
                throw MySQLError(.invalidResponse)
            }
            
            // Capture the error code
            let code = (UInt16(payload[1]) << 8) | UInt16(payload[2])
            
            if mysql41 {
                // MySQL 4.1 errors have an error message payload
                guard self.payload.count > 10 else {
                    throw MySQLError(.invalidResponse)
                }
                
                let state = Response.State(
                    marker: payload[3],
                    state: (payload[4], payload[5], payload[6], payload[7], payload[8])
                )
                
                let message = String(bytes: payload[9...], encoding: .utf8) ?? ""
                
                return .error(Response.Error(code: code, state: state, message: message))
            } else {
                let message = String(bytes: payload[3...], encoding: .utf8) ?? ""
                
                return .error(Response.Error(code: code, state: nil, message: message))
            }
        case 0x00:
            // OK messages
            fallthrough
        case 0xfe:
            // EOF messages
            guard self.payload.count > 3 else {
                throw MySQLError(.invalidResponse)
            }
            
            var parser = Parser(packet: self, position: 1)
            
            let affectedRows = try parser.parseLenEnc()
            let lastInsertedId = try parser.parseLenEnc()
            let statusFlags: UInt16?
            let warnings: UInt16?
            
            if mysql41 {
                statusFlags = try parser.parseUInt16()
                warnings = try parser.parseUInt16()
                
                // TODO: CLIENT_SESSION_TRACK
                // TODO: SERVER_SESSION_STATE_CHANGED
            } else {
                statusFlags = nil
                warnings = nil
            }
            
            // TODO: Client transactions
            
            let data = Data(self.payload[parser.position...])
            
            let ok = Response.OK(affectedRows: affectedRows, lastInsertId: lastInsertedId, status: statusFlags, warnings: warnings, data: data)
            
            if data.count > 0 {
                return .ok(ok)
            } else {
                return .eof(ok)
            }
        default:
            throw MySQLError(.invalidResponse)
        }
    }
}
