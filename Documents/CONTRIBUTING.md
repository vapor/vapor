# Contributing to OSS

If you've never contributed to an OSS project before, here's a <a href="https://akrabat.com/the-beginners-guide-to-contributing-to-a-github-project/">great guide</a> to get you started.

# Building Vapor

The Vapor master branch is occasionally ahead of our release, so the tooling can be a bit different.

## Xcode

In the terminal, `cd` into the repo and build the Xcode Project.

#### Vapor CLI

```Swift
cd path/to/my/project
vapor xcode
```

#### Native SPM

```Swift
cd path/to/my/project
swift package generate-xcodeproj
open *.xcodeproj
```

## Tests

Pull requests without adequate testing may be delayed. Please add tests alongside your pull requests.

## Slack

Join us in the #development channel in slack, for questions and discussions. 
