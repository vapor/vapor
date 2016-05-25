import Fluent

public protocol Model: Fluent.Model, StringInitializable {}

extension Model {
    public init?(from string: String) throws {
        guard let model = try Self.find(string) else {
            return nil
        }
        
        self = model
    }
}
