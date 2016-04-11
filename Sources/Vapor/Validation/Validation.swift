extension String: ErrorProtocol {}

/*
 Possible Naming Conventions

 validated passes Tester -> Verified<T: Tester>
 validated passes TestSuite -> Verified<T: TestSuite>

 tested with (Self -> Bool) -> Self
 tested with Tester -> Self
 tested with TestSuite -> Self
 */

public protocol Validatable {}

// MARK: Validated Returns

extension Validatable {
    // MARK: Designated
    public func tested(@noescape passes tester: (input: Self) throws -> Bool) throws -> Self {
        guard try tester(input: self) else { throw "up" }
        return self
    }
}
