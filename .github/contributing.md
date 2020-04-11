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
