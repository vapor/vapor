import Console

class DebugConsole: ConsoleProtocol {

    let size: (width: Int, height: Int)
    init() {
        size = (0, 0)
        inputBuffer = ""
        outputBuffer = ""
    }

    public var inputBuffer: String
    public var outputBuffer: String

    func input() -> String {
        let temp = inputBuffer
        inputBuffer = ""
        return temp
    }

    func output(_ string: String, style: ConsoleStyle, newLine: Bool) {
        outputBuffer += string
        if newLine {
            outputBuffer += "\n"
        }
    }

    func clear(_ clear: ConsoleClear) { }
    public func execute(program: String, arguments: [String], input: Int32?, output: Int32?, error: Int32?) throws {}
    func subexecute(_ command: String, input: String) throws -> String { return "" }
}
