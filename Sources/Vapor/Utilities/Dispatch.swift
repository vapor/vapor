import Strand

public typealias Block = () -> Void

public func background(function: Block) throws {
    let _ = try Strand(closure: function)
}
