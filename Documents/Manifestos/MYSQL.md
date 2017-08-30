# MySQL Manifesto

## Introduction

MySQL is a popular for web services. It's widely adopted and even familiar under many NoSQL database users.

Thid document serves as a lead for discussing, implementing and accepting code for the `MySQL` package.

## Project goals

### Asynchronous

The source code needs to be written completely for and with asynchronous APIs in mind. Results should be provided either using callbacks, streams or futures.

### Integrated

Operations executed by the connection (such as reading data from the socket) can integrate with an existing DispatchQueue, in order to save the amount of created threads and reduce code complexity.

### Swifty

Swift 4's feature set has to be a first class citizen. This means that this package integrates with relevant Swift 4 features.

MySQL **must** integrate with Codable for decoding rows into entities.

### MVP

MySQL will be written with the minimum amount of API available, and no unfinished features exposed in order to preserve the ability to rewrite parts of unfinshed APIs before exposing them.

### Written in Swift

This project is a "pure-" Swift project, meaning it's entirely written in Swift, with as few possible dependencies that do not contain Swift source code. An example of a package in C would be SSL, since SSL cannot for various reasons be rewritten in Swift and become "usable" to the C libraries' standards.

Reasons to write the driver in Swift:

- Integrate with the language and ecosystem
- Allowing contributors to understand the underlying code at multiple levels of complexity
- Performance can be tweaked towards common Swift use cases (such as Decodable)
- Maintainers gain a better and deeper understanding of the software they're working with
- APIs can be built without relying on C implementations at all, improving API quality
- Setting up the driver is one less installation step (using `apt` or `brew`)

## Code quality

The code quality quality of the MySQL package should follow the official Vapor core module code quality manifesto.
