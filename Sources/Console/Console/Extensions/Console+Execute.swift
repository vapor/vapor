import Bits
import Foundation

// MARK: Foreground

extension ExecuteConsole {
    /// Execute the program using standard IO.
    public func foregroundExecute(program: String, arguments: [String]) throws {
        let stdin = FileHandle.standardInput
        let stdout = FileHandle.standardOutput
        let stderr = FileHandle.standardError

        try execute(
            program: program,
            arguments: arguments,
            input: .fileHandle(stdin),
            output: .fileHandle(stdout),
            error: .fileHandle(stderr)
        )
    }

    /// Execute a program using an array of commands.
    public func foregroundExecute(commands: [String]) throws {
        try foregroundExecute(program: commands[0], arguments: Array(commands.dropFirst(1)))
    }

    /// Execute a program using a variadic array.
    public func foregroundExecute(commands: String...) throws {
        try foregroundExecute(commands: commands)
    }
}

// MARK: Background

extension ExecuteConsole {
    /// Execute the program in the background, returning the result of the run as bytes.
    public func backgroundExecute(program: String, arguments: [String]) throws -> Data {
        let input = Pipe()
        let output = Pipe()
        let error = Pipe()

        try execute(
            program: program,
            arguments: arguments,
            input: .pipe(input),
            output: .pipe(output),
            error: .pipe(error)
        )

        let bytes = output
            .fileHandleForReading
            .readDataToEndOfFile()

        return bytes
    }

    /// Execute the program in the background, intiailizing a type with the returned bytes.
    public func backgroundExecute(program: String, arguments: [String]) throws -> String {
        let data = try backgroundExecute(program: program, arguments: arguments) as Data
        guard let string = String(data: data, encoding: .utf8) else {
            throw ConsoleError(identifier: "executeString", reason: "Could not convert `Data` to `String`: \(data)")
        }
        return string
    }

    /// Execute the program in the background, intiailizing a type with the returned bytes.
    public func backgroundExecute(commands: [String]) throws -> String {
        return try backgroundExecute(program: commands[0], arguments: Array(commands.dropFirst(1)))
    }

    /// Execute the program in the background, intiailizing a type with the returned bytes.
    public func backgroundExecute(commands: String...) throws -> String {
        return try backgroundExecute(commands: commands)
    }
}
