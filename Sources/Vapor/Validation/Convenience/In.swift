/**
    Validate that is in given collection
*/
public struct In<
    T>: Validator where
    T: Validatable,
    T: Equatable
{

    private let iteratorFactory: (Void) -> AnyIterator<T>

    /**
     Create in validation against passed iterator

     - parameter sequence: the sequence to check if contains
    */
    public init<S: Sequence>(_ sequence: S) where S.Iterator.Element == T {
        iteratorFactory = {
            var iterator = sequence.makeIterator()
            return AnyIterator { iterator.next() }
        }
    }


    /**
        validate
    */
    public func validate(input value: T) throws {
        let iterator = iteratorFactory()
        for next in iterator where next == value {
            return
        }
        throw error(with: value)
    }
}
