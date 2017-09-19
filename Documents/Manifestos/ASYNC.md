# Async

Async is a library containing Streams and Futures.

The async library conforms to the [vapor code quality manifesto](CODE_QUALITY.md).

## Library Goals

The Vapor Async library's goal is to provide an asynchronous, performant layer of communication between components of any library.

This library contains the core protocols and functionalities that are necessary for every library or (indirect) user of these features.

In addition to the necessary functionalities, this library also adds helpers to the fundamental functionalities that are necessary for a simple and clean workflow using these functionalities.

This library needs to be simple and independent, so that it can be easily and without consideration be used in foreign libraries (outside of the Vapor project).

## Scope

Anything not directly a goal is out of scope.

## API Goals

To provide a clean, readable and comprehensible way of writing asynchronous code.

## How it's achieved

Streams and futures are all around us in both the digital and virtual world. Everything happens at an unspecified time. And everything is a single or chain of events.

Computers are almost entirely streams of data. And when it's not a stream of data, it's a single event. Anything that's not an event at all is never part of the system in the first place.

There are three kinds of information:

- Event
- Error
- End of events

The end of events marks the end of a stream. Like a TCP socket being closed, or (in the real world) a faucet being closed.

## Why

Asynchronous is important for a web framework like vapor and it's components to keep all components both scalable and maintainable.

The added achievement to this project is the increased performance, readability and maintainability of code.
