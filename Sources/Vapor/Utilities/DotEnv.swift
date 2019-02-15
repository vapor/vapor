#if os(Linux)
import Glibc
#else
import Darwin
#endif

/// Reads dotenv (`.env`) files and loads them into the current process.
///
///     let fileio: NonBlockingFileIO
///     let elg: EventLoopGroup
///     let file = try DotEnvFile.read(path: ".env", fileio: fileio, on: elg.next()).wait()
///     for line in file.lines {
///         print("\(line.key)=\(line.value)")
///     }
///     file.load(overwrite: true) // loads all lines into the process
///
/// Dotenv files are formatted using `KEY=VALUE` syntax. They support comments using the `#` symbol.
/// They also support strings, both single and double-quoted.
///
///     FOO=BAR
///     STRING='Single Quote String'
///     # Comment
///     STRING2="Double Quoted\nString"
///
/// Single-quoted strings are parsed literally. Double-quoted strings may contain escaped newlines
/// that will be converted to actual newlines.
public struct DotEnvFile {
    /// Reads a dotenv file from the supplied path and loads it into the process.
    ///
    ///     let fileio: NonBlockingFileIO
    ///     let elg: EventLoopGroup
    ///     try DotEnvFile.load(path: ".env", fileio: fileio, on: elg.next()).wait()
    ///     print(Environment.process.FOO) // BAR
    ///
    /// Use `DotEnvFile.read` to read the file without loading it.
    ///
    /// - parameters:
    ///     - path: Absolute or relative path of the dotenv file.
    ///     - fileio: File loader.
    ///     - eventLoop: Eventloop to perform async work on.
    ///     - overwrite: If `true`, values already existing in the process' env
    ///                  will be overwritten. Defaults to `false`.
    public static func load(
        path: String,
        fileio: NonBlockingFileIO,
        on eventLoop: EventLoop,
        overwrite: Bool = false
    ) -> EventLoopFuture<Void> {
        return self.read(path: path, fileio: fileio, on: eventLoop)
            .map { $0.load(overwrite: overwrite) }
    }
    
    /// Reads a dotenv file from the supplied path.
    ///
    ///     let fileio: NonBlockingFileIO
    ///     let elg: EventLoopGroup
    ///     let file = try DotEnvFile.read(path: ".env", fileio: fileio, on: elg.next()).wait()
    ///     for line in file.lines {
    ///         print("\(line.key)=\(line.value)")
    ///     }
    ///     file.load(overwrite: true) // loads all lines into the process
    ///     print(Environment.process.FOO) // BAR
    ///
    /// Use `DotEnvFile.load` to read and load with one method.
    ///
    /// - parameters:
    ///     - path: Absolute or relative path of the dotenv file.
    ///     - fileio: File loader.
    ///     - eventLoop: Eventloop to perform async work on.
    public static func read(
        path: String,
        fileio: NonBlockingFileIO,
        on eventLoop: EventLoop
    ) -> EventLoopFuture<DotEnvFile> {
        return fileio.openFile(path: path, eventLoop: eventLoop).flatMap { arg -> EventLoopFuture<ByteBuffer> in
            return fileio.read(fileRegion: arg.1, allocator: .init(), eventLoop: eventLoop)
                .flatMapThrowing
            { buffer in
                try arg.0.close()
                return buffer
            }
        }.map { buffer in
            var parser = Parser(source: buffer)
            return .init(lines: parser.parse())
        }
    }
    
    /// Represents a `KEY=VALUE` pair in a dotenv file.
    public struct Line: CustomStringConvertible {
        /// The key.
        public let key: String
        
        /// The value.
        public let value: String
        
        /// `CustomStringConvertible` conformance.
        public var description: String {
            return "\(self.key)=\(self.value)"
        }
    }
    
    /// All `KEY=VALUE` pairs found in the file.
    public let lines: [Line]
    
    /// Creates a new DotEnvFile
    init(lines: [Line]) {
        self.lines = lines
    }
    
    /// Loads this file's `KEY=VALUE` pairs into the current process.
    ///
    ///     let file: DotEnvFile
    ///     file.load(overwrite: true) // loads all lines into the process
    ///
    /// - parameters:
    ///     - overwrite: If `true`, values already existing in the process' env
    ///                  will be overwritten. Defaults to `false`.
    public func load(overwrite: Bool = false) {
        for line in self.lines {
            setenv(line.key, line.value, overwrite ? 1 : 0)
        }
    }
}

// MARK: Private

private extension DotEnvFile {
    struct Parser {
        var source: ByteBuffer
        init(source: ByteBuffer) {
            self.source = source
        }
        
        mutating func parse() -> [Line] {
            var lines: [Line] = []
            while let next = self.parseNext() {
                lines.append(next)
            }
            return lines
        }
        
        private mutating func parseNext() -> Line? {
            self.skipSpaces()
            guard let peek = self.peek() else {
                return nil
            }
            switch peek {
            case .octothorpe:
                // comment following, skip it
                self.skipComment()
                // then parse next
                return self.parseNext()
            case .newLine:
                // empty line, skip
                self.pop() // \n
                // then parse next
                return self.parseNext()
            default:
                // this is a valid line, parse it
                return self.parseLine()
            }
        }
        
        private mutating func skipComment() {
            guard let commentLength = self.countDistance(to: .newLine) else {
                return
            }
            self.source.moveReaderIndex(forwardBy: commentLength + 1) // include newline
        }
        
        private mutating func parseLine() -> Line? {
            guard let keyLength = self.countDistance(to: .equal) else {
                return nil
            }
            guard let key = self.source.readString(length: keyLength) else {
                return nil
            }
            self.pop() // =
            guard let value = self.parseLineValue() else {
                return nil
            }
            self.pop() // \n
            return Line(key: key, value: value)
        }
        
        private mutating func parseLineValue() -> String? {
            guard let valueLength = self.countDistance(to: .newLine) else {
                return nil
            }
            guard let value = self.source.readString(length: valueLength) else {
                return nil
            }
            guard let first = value.first, let last = value.last else {
                return value
            }
            // check for quoted strings
            switch (first, last) {
            case ("\"", "\""):
                // double quoted strings support escaped \n
                return value.dropFirst().dropLast()
                    .replacingOccurrences(of: "\\n", with: "\n")
            case ("'", "'"):
                // single quoted strings just need quotes removed
                return value.dropFirst().dropLast() + ""
            default: return value
            }
        }
        
        private mutating func skipSpaces() {
            scan: while let next = self.peek() {
                switch next {
                case .space: self.pop()
                default: break scan
                }
            }
        }
        
        private func peek() -> UInt8? {
            return self.source.getInteger(at: self.source.readerIndex)
        }
        
        private mutating func pop() {
            self.source.moveReaderIndex(forwardBy: 1)
        }
        
        private func countDistance(to byte: UInt8) -> Int? {
            var copy = self.source
            scan: while let next = copy.readInteger(as: UInt8.self) {
                if next == byte {
                    break scan
                }
            }
            let distance = copy.readerIndex - source.readerIndex
            guard distance != 0 else {
                return nil
            }
            return distance - 1
        }
    }
}

private extension UInt8 {
    static var newLine: UInt8 {
        return 0xA
    }
    
    static var space: UInt8 {
        return 0x20
    }
    
    static var octothorpe: UInt8 {
        return 0x23
    }
    
    static var equal: UInt8 {
        return 0x3D
    }
}
