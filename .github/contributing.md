# Contributing to Vapor

👋 Welcome to the Vapor team! 

## Testing

If you are using Xcode, select the `vapor-Package` scheme and use `CMD+U` to run the tests.

If you are using VS Code, you can run the tests from the [Test Explorer view](https://docs.swift.org/latest/documentation/userdocs/test-explorer) using [the Swift Extension for VS Code](https://marketplace.visualstudio.com/items?itemName=swiftlang.swift-vscode).

You can use the `Development` executables for testing out your code.

```sh
swift run Development
```

If you want to run the development server with TLS enabled, use the command below:

```sh
swift run Development --vapor-env tls
```

Don't forget to add tests for your new features.

If you are fixing a single GitHub issue in particular, you can add a test with a `.bug("https://github.com/vapor/vapor/issues/<issue number>")` trait to ensure that your fix is working.
This will also help prevent regression.
See [Associating bugs with tests](https://docs.swift.org/latest/documentation/testing/associatingbugs) for more information.

### Dev container

To easily test and develop Vapor on Linux from macOS, you can use the provided development container in the `.devcontainer` directory.

## API Documentation

Make sure that any new public API is covered by API documentation and update any existing documentation where relevant. See [Writing Symbol Documentation in Your Source Files](https://docs.swift.org/latest/documentation/docc/writing-symbol-documentation-in-your-source-files) and [DocC](https://docs.swift.org/latest/documentation/docc) for more information.

## Style Guide

When contributing code to Vapor, please try to follow existing style for consistency.

### Formatting

Vapor uses `swift-format` for formatting code.

To format the code, run the following command:

```sh
swift format --parallel --in-place --recursive .
```

To check if the code is properly formatted, you can run the following command:

```sh
swift format lint --parallel --strict --recursive .
```

### Explicit self

When accessing member properties and methods, use explicit `self`. 

```swift
struct Foo {
    var bar: Int
    func baz() {
        // ❌
        print(bar)
        // ✅
        print(self.bar)
    }
}
```

This makes it easier to tell whether a local variable is being used or not, especially when reading code without syntax highlighting.

## SemVer

Vapor follows [SemVer](https://semver.org). This means that any changes to the source code that can cause
existing code to stop compiling _must_ wait until the next major version to be included. 

Code that is only additive and will not break any existing code can be included in the next minor release.

## Releases

All `vapor/*` packages use automated releases. When a PR is merged, the Vapor bot [Penny](https://github.com/vapor/penny-bot) will check for certain PR labels and ship a new release right away. This ensures users get access to new features as soon as possible and helps to reduce human error. 

The release will use the PR's title and body directly. It will also include a note about who authored the release and who merged it. 

### Release title

The release title should be concise description. For example:

- ✅ HTTP streaming improvements 
- ✅ Add case-insensitive routing
- ✅ Fix `routes` command symbol usage

The release titles should use sentence capitalization and not be too verbose. They should also use present tense.

- ❌ Fix `routes` Command Symbol Usage
- ❌ Add new method on RouteBuilder called `caseInsensitive` which can be used to enable case-insensitive routing 
- ❌ Fixed `routes` command symbol usage

### Release body

The release body (or description) should contain more in-depth information about the change and code examples if possible. 

✅

````md

Allows configuring case-insensitive routing (#2354, fixes #1928).

```swift
// Enables case-insensitive routing.
// Defaults to false.
app.routes.caseInsensitive = true
```

````

The release body should include links to any associated PRs and issues. Issues that are fixed by this change should be prefixed with `fixes` so that they are closed automatically. The first line of the release body should be a concise description of the change. This can be followed by a more detailed explanation and code examples. 

Releases with a large number of changes can separated using bullets. Special comments or notes can be added using quote blocks `>`. 

✅

```md

Improves HTTP request and response streaming (#2404).

- Streaming request body skipping will only happen if the entire response has been sent before the user _starts_ reading the request body (fixes #2393).

> Note: Previously, streaming request bodies would be drained automatically by Vapor as soon as the response head was sent. This made it impossible to implement realtime streaming, like an echo server. With these changes, you have much more control over streaming HTTP while still preventing hanging if the request body is ignored entirely. 

- Response body stream now supports omitting the `count` parameter (fixes #2393).

> Note: Previously streaming bodies required a count and would always set the `content-length` header. Now, setting a count of `-1` indicates a stream with indeterminate length. `-1` will be used if the stream count is omitted. This results in `transfer-encoding: chunked` being used automatically. 

```

Release bodies should be in present tense third person. They should mention only information relevant to release notes. Any additional information or questions can be included in PR comments.

❌

```md

I've implemented two fixes to HTTP request streaming. I'm wondering if I need to implement three?

Here's what I've done so far:

...

```

The following PR labels are supported by Vapor's release bot.

- `semver-patch`: Bumps the patch version. 0.0.x
- `semver-minor`: Bumps the minor version: 0.x.0
- `semver-major`: Bumps the major version: x.0.0 (rarely used)
- `release`: Advances the pre-release identifier (alpha -> beta -> rc)

When Vapor's release bot makes a release, it will automatically notify the `#release` channel in Vapor's team chat and include a link to the release on the merged PR.

----------

Join us on Discord if you have any questions: [http://vapor.team](http://vapor.team).

&mdash; Thanks! 🙌
