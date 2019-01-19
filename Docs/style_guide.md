# Style Guide


## Curly Braces

### Function Definitions

Function starting curly braces go on the same line as the function signiture and
ending curly braces go on the line after the function definition.

```swift
public func encode(using container: Container) throws -> Future<Request> {
    let req = Request(using: container)
    try req.content.encode(self)
    return Future.map(on: container) { req }
}
```

### Extensions

See Function Definitions

```swift
extension Int32: Content {
    /// See `Content`.
    public static var defaultContentType: MediaType {
        return .plainText
    }
}
```

### Computed Variables

See Function Definitions

```swift
/// See `Content`.
public static var defaultContentType: MediaType {
    return .plainText
}
```

Getters and setters are a single line if they're small enough.

```swift
public static var defaultDatabase: DatabaseIdentifier<Database>? {
    get { return _defaultDatabases[ObjectIdentifier(Self.self)] as? DatabaseIdentifier<Database> }
    set { _defaultDatabases[ObjectIdentifier(Self.self)] = newValue }
}
```

### Closures

If closure definitons are small enough to fit on one line, then the starting and ending
curly brace should be on the same line.

```swift
return Future.map(on: container) { req }
```

## Line Length and Line Breaks

The maximum length for a line of code is XXXXXXX characters. Anything larger than that 
is required to break.

### Function Signitures

If a function signiture gets to long, break so that each parameter is at the same indentation
and one tab in from the start of the signiture. The ending parenthases and curly brace goes
on its own line at the same indentation as the start of the signiture.

```swift
internal init(
    httpEncoders: [MediaType: HTTPMessageEncoder],
    httpDecoders: [MediaType: HTTPMessageDecoder],
    dataEncoders: [MediaType: DataEncoder],
    dataDecoders: [MediaType: DataDecoder]
) {
    self.httpEncoders = httpEncoders
    self.httpDecoders = httpDecoders
    self.dataEncoders = dataEncoders
    self.dataDecoders = dataDecoders
}
```

## Initializers

### Arrays

```swift
// Preferred
let foo = [String]()

// Not preferred
let foo: [String] = []
```

## Misc

### Colons
No matter whether it's a type anotation or in the middle of a dictionary, colons are always followed by a space.

```swift
private var dataDecoders: [MediaType: DataDecoder]
```
