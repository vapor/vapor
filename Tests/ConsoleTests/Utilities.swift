import Async
import Console
import Service

final class TestConsole: Console {
    var output: String
    var input: String
    var error: String
    var extend: Extend

    init() {
        self.output = ""
        self.input = ""
        self.error = ""
        self.extend = Extend()
    }

    func clear(_ type: ConsoleClear) {

    }

    func execute(program: String, arguments: [String], input: ExecuteStream?, output: ExecuteStream?, error: ExecuteStream?) throws {
    }

    func input(isSecure: Bool) -> String {
        let t = input
        input = ""
        return t
    }

    func output(_ string: String, style: ConsoleStyle, newLine: Bool) {
        self.output += string + (newLine ? "\n" : "")
    }

    func report(error: String, newLine: Bool) {
        self.error += error + (newLine ? "\n" : "")
    }

    var size: (width: Int, height: Int) {
        return (640, 320)
    }
}
