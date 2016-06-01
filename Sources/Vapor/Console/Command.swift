public protocol Command {
    static var id: String { get }
    static var help: [String] { get }
    static func run(on app: Application, with arguments: [String])
}

extension Command {
    public static var help: [String] {
        return []
    }
}
