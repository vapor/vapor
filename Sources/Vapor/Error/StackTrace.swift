public struct StackTrace {
    public static func capture() -> Self {
        .init(raw: Thread.callStackSymbols)
    }

    public var frames: [Frame] {
        self.raw.dropFirst(2).map { line in
            let parts = line.split(
                separator: " ",
                maxSplits: 3,
                omittingEmptySubsequences: true
            )
            let file = String(parts[1])
            let functionParts = parts[3].split(separator: "+")
            let mangledName = String(functionParts[0]).trimmingCharacters(in: .whitespaces)
            let function = _stdlib_demangleName(mangledName)
            return Frame(file: file, function: function)
        }
    }

    public struct Frame {
        var file: String
        var function: String
    }

    let raw: [String]

    public func description(max: Int = 16) -> String {
        self.frames[...min(self.frames.count, max)].readable
    }
}

extension StackTrace: CustomStringConvertible {
    public var description: String {
        self.description()
    }
}

extension StackTrace.Frame: CustomStringConvertible {
    public var description: String {
        "\(self.file) \(self.function)"
    }
}

extension Collection where Element == StackTrace.Frame {
    var readable: String {
        let maxIndexWidth = String(self.count).count
        let maxFileWidth = self.map { $0.file.count }.max() ?? 0
        return self.enumerated().map { (i, frame) in
            let indexPad = String(
                repeating: " ",
                count: maxIndexWidth - String(i).count
            )
            let filePad = String(
                repeating: " ",
                count: maxFileWidth - frame.file.count
            )
            return "\(i)\(indexPad) \(frame.file)\(filePad) \(frame.function)"
        }.joined(separator: "\n")
    }
}
