// Might have to tweak for linux
import Foundation

public struct Unique<
    T where
    T: Sequence,
    T: Validatable,
    T.Iterator.Element: Equatable>: ValidationSuite {

    public static func validate(input sequence: T) throws {
        var uniqueValues: [T.Iterator.Element] = []
        for value in sequence {
            if uniqueValues.contains(value) {
                throw error(with: sequence)
            } else {
                uniqueValues.append(value)
            }
        }
    }
}

public struct In<
    T where
    T: Validatable,
    T: Equatable>: Validator {

    private let iteratorFactory: Void -> AnyIterator<T>

    public init<S: Sequence where S.Iterator.Element == T>(_ sequence: S) {
        iteratorFactory = {
            var iterator = sequence.makeIterator()
            return AnyIterator { iterator.next() }
        }
    }

    public func validate(input value: T) throws {
        let iterator = iteratorFactory()
        for next in iterator where next == value {
            return
        }
        throw error(with: value)
    }
}

public struct Contains<
    T where
    T: Sequence,
    T: Validatable,
    T.Iterator.Element: Equatable>: Validator {

    /**
        The value expected to be in sequence
    */
    public let expecting: T.Iterator.Element

    /**
        Create a validator to check that a sequence contains the given value

        - parameter expecting: the value expected to be in sequence
     */
    init(_ expecting: T.Iterator.Element) {
        self.expecting = expecting
    }

    /**
        validate
    */
    public func validate(input sequence: T) throws {
        for element in sequence where element == expecting {
            return
        }

        throw error(with: sequence)
    }
}
