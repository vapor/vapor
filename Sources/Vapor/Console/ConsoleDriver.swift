/**
    Objects capable of sending output to
    and receiving input from a console can
    conform to this protocol to power the Console.
*/
public protocol ConsoleDriver {
    func output(_ string: String, style: Console.Style, newLine: Bool)
    func input() -> String
}
