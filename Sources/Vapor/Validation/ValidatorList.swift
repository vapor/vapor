public final class ValidatorList<Input: Validatable>: Validator {
    public private(set) var validators: [(Input) throws -> Void] = []

    internal init() {}

    internal init<V: Validator>(_ validator: V) where V.Input == Input {
        extend(validator)
    }

    internal func extend<V: Validator>(_ v: V) where V.Input == Input {
        validators.append(v.validate)
    }

    internal func extend(_ v: @escaping (Input) throws -> Void) {
        validators.append(v)
    }

    public func validate(_ input: Input) throws {
        var failures = [Error]()

        validators.forEach { validator in
            do {
                try validator(input)
            } catch let error as ErrorList {
                failures += error.errors
            } catch {
                failures.append(error)
            }
        }

        if !failures.isEmpty { throw ErrorList(failures) }
    }
}
