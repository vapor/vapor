import Strand

public typealias Block = () -> Void

public func Background(function: Block) throws {
    let _ = try Strand(closure: function)
}
