import Foundation

extension Array where Element == UInt8 {
    mutating func write(string: String) {
        if string.utf8.withContiguousStorageIfAvailable({ storage in
            self.append(contentsOf: storage)
        }) == nil {
            (string + "").utf8.withContiguousStorageIfAvailable({ storage in
                self.append(contentsOf: storage)
            })!
        }
    }
}

extension HTTPHeaders {
    func getParameter(_ name: String, _ key: String) -> String? {
        return self.headerParts(name: name).flatMap {
            $0.filter { $0.hasPrefix("\(key)=") }
                .first?
                .split(separator: "=")
                .last
                .flatMap { $0 .trimmingCharacters(in: .quotes)}
        }
    }
    
    mutating func setParameter(
        _ name: String,
        _ key: String,
        to value: String?,
        defaultValue: String
    ) {
        var current: [String]
        if let existing = self.headerParts(name: name) {
            current = existing.filter { !$0.hasPrefix("\(key)=") }
        } else {
            current = [defaultValue]
        }
        if let value = value {
            current.append("\(key)=\"\(value)\"")
        }
        let new = current.joined(separator: "; ")
            .trimmingCharacters(in: .whitespaces)
        self.replaceOrAdd(name: name, value: new)
    }
    
    func headerParts(name: String) -> [String]? {
        return self[name]
            .first
            .flatMap {
                $0.split(separator: ";")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
            }
    }
}



extension CharacterSet {
    static var quotes: CharacterSet {
        return .init(charactersIn: #""'"#)
    }
}

extension DataProtocol {
    func copyBytes() -> [UInt8] {
        var buffer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: self.count)
        self.copyBytes(to: buffer)
        defer { buffer.deallocate() }
        return .init(buffer)
    }
}
