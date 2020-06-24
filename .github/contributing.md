# Contributing to Vapor

👋 Welcome to the Vapor team! 

## Testing

Once in Xcode, select the `vapor-Package` scheme and use `CMD+U` to run the tests.

You can use the `Development` executables for testing out your code.

Don't forget to add tests for your new features.

If you are fixing a single GitHub issue in particular, you can add a test named `testGH<issue number>` to ensure
that your fix is working. This will also help prevent regression.

## SemVer

Vapor follows [SemVer](https://semver.org). This means that any changes to the source code that can cause
existing code to stop compiling _must_ wait until the next major version to be included. 

Code that is only additive and will not break any existing code can be included in the next minor release.

## Releases

All vapor/* packages use automated releases. When a PR is merged, the Vapor bot will check for certain PR labels and ship a new release right away. This ensures users get access to new features as soon as possible and helps to reduce human error. 

The release will use the PR's title and body directly. It will also include a note about who authored the release and who merged it. 

### Release title

The release title should be concise description of the change using normal sentence capitalization. For example:

- ✅ HTTP streaming improvements 
- ✅ Add case-insensitive routing
- ✅ Fix `routes` command symbol usage

The release titles should not be too verbose. They should also use present tense.

- ❌ Add new method on RouteBuilder called `caseInsensitive` which can be used to enable case-insensitive routing 
- ❌ Fixed `routes` command symbol usage

### Release body

The release body (or description) should contain more in-depth information about the change code examples if possible. 

✅

---

Allows configuring case-insensitive routing (#2354, fixes #1928).

```swift
// Enables case-insensitive routing.
// Defaults to false.
app.routes.caseInsensitive = true
```

---

It should include a link to any associated PRs and issues. Issues that are fixed by this change should be prefixed with `fixes` so that they are closed automatically. The first line of the release body should be a concise description of the change. This can be followed by a more detailed explanation and code examples. 

Releases with a large number of changes can separated using bullets. Special comments or notes can be added using quote blocks `>`. 

✅

---

Improves HTTP request and response streaming (#2404).

- Streaming request body skipping will only happen if the entire response has been sent before the user _starts_ reading the request body (fixes #2393).

> Note: Previously, streaming request bodies would be drained automatically by Vapor as soon as the response head was sent. This made it impossible to implement realtime streaming, like an echo server. With these changes, you have much more control over streaming HTTP while still preventing hanging if the request body is ignored entirely. 

- Response body stream now supports omitting the `count` parameter (fixes #2393).

> Note: Previously streaming bodies required a count and would always set the `content-length` header. Now, setting a count of `-1` indicates a stream with indeterminate length. `-1` will be used if the stream count is omitted. This results in `transfer-encoding: chunked` being used automatically. 

---

Release bodies should be in present tense third person. They should mention only information relevant to release notes. Any additional information or questions can be included in PR comments.

❌

---

I've implemented two fixes to HTTP request streaming. I'm wondering if I need to implement three?

Here's what I've done so far:

...

---

The following PR labels are supported by Vapor's release bot.

- `semver-patch`: Bumps the patch version. 0.0.x
- `semver-minor`: Bumps the minor version: 0.x.0
- `semver-major`: Bumps the major version: x.0.0 (rarely used)
- `release`: Advances the pre-release identifier (alpha -> beta -> rc)

When Vapor's release bot makes a release, it will automatically notify the `#release` channel in Vapor's team chat and include a link to the release on the merged PR.

## Maintainers

Each repo under the Vapor organization has at least one [volunteer maintainer.](maintainers.md) [vapor/vapor's](https://github.com/vapor/vapor) current list of maintainers is:

- [@tanner0101](https://github.com/tanner0101)
- [@MrLotU](https://github.com/MrLotU)
- [@Joannis](https://github.com/Joannis)

## Extras

Here are some bash functions to help you test Swift on Linux easily from macOS (you must have Docker installed).

### Swift Linux

```bash
# Starts docker-machine and exports env variables.
_docker_start() {
    docker-machine start default
    eval "$(docker-machine env default)"
}
alias docker-start='_docker_start'

# Executes /usr/bin/swift in a Swift 4.1 docker container
_swift_linux() {
    _docker_start
    docker run -it -v $PWD:/root/code -w /root/code norionomura/swift:swift-4.1-branch /usr/bin/swift $1
}
alias swift-linux='_swift_linux'
```

You can add these methods to your `~/.bash_profile`. Just run `source ~/.bash_profile` after or restart your terminal.

Once added, you can run the following to test Swift projects on both macOS and Linux.

```sh
swift test
swift-linux test
```

### Clean SPM

Add the following code to your bash profile to make cleaning SPM temporary files easy.

```bash
# Cleans out all temporary SPM files
_spm_clean() {
	rm Package.resolved
	rm -rf .build
	rm -rf *.xcodeproj
	rm -rf Packages
}
alias spm-clean='_spm_clean'
```

Once added, you can run `spm-clean`.

```sh
spm-clean
```

----------

Join us on Discord if you have any questions: [http://vapor.team](http://vapor.team).

&mdash; Thanks! 🙌
