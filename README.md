![Vapor](https://cloud.githubusercontent.com/assets/1342803/12457776/87e20994-bf74-11e5-8942-200a0238af12.png)

# Vapor

A Laravel/Lumen Inspired Web Framework for Swift that works on iOS, OS X, and Ubuntu.

## Getting Started

Clone the [Example](https://github.com/tannernelson/vapor-example) project to start making your application. This repository is for the framework module.

You must have Swift 2.2 or later installed. You can learn more about Swift 2.2 at [Swift.org](http://swift.org)

### Work in Progress

This is a work in progress, so don't rely on this for anything important. And pull requests are welcome!

## Server

Starting the server takes two lines.

`main.swift`
```swift
import Vapor

let server = Server()
server.run()
```

You can also choose which port the server runs on.

```swift
server.run(port: 8080)
```

If you are having trouble connecting, make sure your ports are open. Check out `apt-get ufw` for simple port management.

## Routing

Routing in Vapor is simple and very similar to Laravel.

`main.swift`
```swift
Route.get("welcome") { request in
	return "Hello"
}

//...start server
```

Here we will respond to all requests to `http://example.com/welcome` with the string `"Hello"`. 

### JSON

Responding with JSON is easy.

```swift
Route.get("version") { request in
	return ["version": "1.0"]
}
```

This responds to all requests to `http://example.com/version` with the JSON dictionary `{"version": "1.0"}` and correct headers.

### Views

You can also respond with HTML pages.

```swift
Route.get("/") { request in
	return View(path: "index.html")
}
```

Just put the `index.html` in the `Resources` folder at the root of your project and it will be served.

### Public

All files put in the `Public` folder at the root of your project will be available at the root of your domain. This is a great place to put your assets (`.css`, `.js`, `.png`, etc).

## Request

Every route call gets passed a `Request` object. This can be used to grab query and path parameters.

This is a list of the properties available on the request object.

```swift
public let method: Method
public var parameters: [String: String] = [:]
public var query: [String: String] = [:]
```

## Controllers

Controllers are great for keeping your code organized. `Route` directives can take whole controllers or controller methods as arguments instead of closures.

`main.swift`
```swift
Route.get("/heartbeat/alternate", closure: HeartbeatController().index)
```

To pass a function name as a closure like above, the closure must have the function signature 

```swift
func index(request: Request) -> AnyObject
```

Here is an example of a controller for returning an API heartbeat.

`HearbeatController.swift`
```swift
import Vapor

class HeartbeatController: Controller {

	override func index(request: Request) -> AnyObject {
		return ["lub": "dub"]
	}

}
```

Here the `HeartbeatControllers`'s index method will be called when `http://example.com/heartbeat/alternate` is visited.

### Resource Controllers

Resource controllers take advantage of CRUD-like `index`, `show`, `store`, `update`, `destroy` methods to make setting up REST APIs easy.

```swift
Route.resource("/user", controller: UserController()) //not yet implemented
```

This will create the appropriate `GET`, `POST`, `DELETE`, etc methods for individual and groups of users. 

## Deploying

Vapor has been successfully tested on Ubuntu 14.04 LTS (DigitalOcean) and Ubuntu 15.10 (VirtualBox). 

To deploy to DigitalOcean, simply 

- Install Swift 2.2
	- `wget` the .tar.gz from Apple
	- Set the `export PATH` in your `~/.bashrc`
	- (you may need to install `binutils` as well if you see `ar not found`)
- Clone your fork of the `vapor-example` repository to the server
- `cd` into the repository
	- Run `swift build`
	- Run `.build/debug/MyApp`
	- (you may need to run as `sudo` to use certain ports)
	- (you may need to install `ufw` to set appropriate ports)

My website `http://tanner.xyz` is currently running using this Vapor.

## Swifter

This project is based on [Swifter](https://github.com/glock45/swifter)
