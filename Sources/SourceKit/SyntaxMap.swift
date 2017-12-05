import Bits
import Foundation

public struct Syntax {
    var kind: String
    var offset: Int
    var length: Int
}

public struct SyntaxMap {
    let items: [Syntax]
    let data: Data

    init(_ data: Data, _ items: [Syntax]) {
        self.data = data
        self.items = items
    }
}

extension SyntaxMap {
    func comments(beforeOffset: Int) -> [String]? {
        guard let index = items.index(where: { syntax in
            return syntax.offset == beforeOffset
        }) else {
            return nil
        }

        var lines: [String] = []

        for i in (0..<index).reversed() {
            let test = items[i]
            if test.kind.hasSuffix("comment") {
                let chunk = data[test.offset..<(test.offset + test.length)]

                var line = String(data: chunk, encoding: .utf8) ?? ""

                if line.hasPrefix("///") {
                    line = String(line.dropFirst(3))
                } else if line.hasPrefix("//") {
                    line = String(line.dropFirst(2))
                } else if line.hasPrefix("/*") {
                    line = String(line.dropFirst(2))
                } else if line.hasPrefix("*/") {
                    line = String(line.dropLast(2))
                }
                if line.hasSuffix("\n") {
                    line = String(line.dropLast())
                }
                lines.append(line)
            } else {
                break
            }
        }

        if lines.count == 0 {
            return nil
        }

        return lines
    }
}
