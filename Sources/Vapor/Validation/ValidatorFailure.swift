public protocol ValidatorFailure {}

public struct MissingRequiredValueFailure: ValidatorFailure {}

public struct TypeMismatchValidatorFailure: ValidatorFailure {}
