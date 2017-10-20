import Foundation

fileprivate let PKCSHeader = "-----";
fileprivate let PKCS1PublicHeader = "BEGIN RSA PUBLIC KEY";
fileprivate let PKCS8PublicHeader = "BEGIN PUBLIC KEY";
fileprivate let PKCS1PublicFooter = "END RSA PUBLIC KEY";
fileprivate let PKCS8PublicFooter = "END PUBLIC KEY";

fileprivate let PKCS1PrivateHeader = "BEGIN RSA PRIVATE KEY";
fileprivate let PKCS8PrivateHeader = "BEGIN PRIVATE KEY";
fileprivate let PKCS1PrivateFooter = "END RSA PRIVATE KEY";
fileprivate let PKCS8PrivateFooter = "END PRIVATE KEY";

fileprivate let PKCS8PrivateEncryptedHeader = "BEGIN ENCRYPTED PRIVATE KEY";
fileprivate let PKCS8PrivateEncryptedFooter = "END ENCRYPTED PRIVATE KEY";

enum PEMError: Error {
    case invalidFormat
}

public final class PEM {
    public init(data: Data) {
        
    }
    
    public static func parse(_ data: String) throws -> PEM {
        var index = data.startIndex
        
        func matchAdvance(_ string: String) -> Bool {
            guard let next = data.index(index, offsetBy: string.characters.count, limitedBy: data.endIndex) else {
                return false
            }
            
            guard next <= data.endIndex, data[index..<next] == string else {
                return false
            }
            
            index = next
            
            return true
        }
        
        func assertHeaderBoundary() throws {
            guard matchAdvance(PKCSHeader) else {
                throw PEMError.invalidFormat
            }
        }
        
        func assertHeader(_ string: String) throws {
            guard matchAdvance(string) else {
                throw PEMError.invalidFormat
            }
        }
        
        func scanBase64String() throws -> String {
            var endIndex = data.index(after: index)
            
            while endIndex < data.endIndex {
                if data[endIndex] == PKCSHeader.first {
                    defer { index = endIndex }
                    
                    return String(data[index..<endIndex])
                }
                
                endIndex = data.index(after: endIndex)
            }
            
            throw PEMError.invalidFormat
        }
        
        func parseBase64() throws -> Data {
            let string = try scanBase64String().replacingOccurrences(of: "\n", with: "")
            return try Base64Decoder.decode(string: string)
        }
        
        try assertHeaderBoundary()
        
        let pem: Data
        
        if matchAdvance(PKCS1PublicHeader) {
            try assertHeaderBoundary()
            
            pem = try parseBase64()
            
            try assertHeaderBoundary()
            try assertHeader(PKCS1PublicFooter)
            try assertHeaderBoundary()
        } else if matchAdvance(PKCS8PublicHeader) {
            try assertHeaderBoundary()
            
            pem = try parseBase64()
            
            try assertHeaderBoundary()
            try assertHeader(PKCS8PublicFooter)
            try assertHeaderBoundary()
        } else if matchAdvance(PKCS1PrivateHeader) {
            try assertHeaderBoundary()
            
            pem = try parseBase64()
            
            try assertHeaderBoundary()
            try assertHeader(PKCS1PrivateFooter)
            try assertHeaderBoundary()
        } else if matchAdvance(PKCS8PrivateHeader) {
            try assertHeaderBoundary()
            
            pem = try parseBase64()
            
            try assertHeaderBoundary()
            try assertHeader(PKCS8PrivateFooter)
            try assertHeaderBoundary()
        } else if matchAdvance(PKCS8PrivateEncryptedHeader) {
            try assertHeaderBoundary()
            
            pem = try parseBase64()
            
            try assertHeaderBoundary()
            try assertHeader(PKCS8PrivateEncryptedFooter)
            try assertHeaderBoundary()
        } else {
            throw PEMError.invalidFormat
        }
        
        return PEM(data: pem)
    }
}
