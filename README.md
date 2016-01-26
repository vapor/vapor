![Vapor](https://cloud.githubusercontent.com/assets/1342803/12457900/1825c70c-bf75-11e5-9080-989345fa43e2.png)

# Vapor

A Laravel/Lumen Inspired Web Framework for Swift that works on iOS, OS X, and Ubuntu.

- [x] Insanely fast
- [x] Beautiful syntax
- [x] Type safe

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

This responds to all requests to `http://example.com/version` with the JSON dictionary `{"version": "1.0"}` and `Content-Type: application/json`.

### Views

You can also respond with HTML pages.

```swift
Route.get("/") { request in
	return View(path: "index.html")
}
```

Or Mustache templates (coming soon).

`index.mustache`

```mustache
<html>
	<h1>{{ message }}</h1>
</html>
```

```swift
Route.get("/") { request in
	return View(path: "index.mustache", ["message": "Hello"])
}
```

Just put the View file in the `Resources` folder at the root of your project and it will be served.

### Response

A manual response can be returned if you want to set something like `cookies`.

```swift
Route.get("cookie") { request in
	let response = Response(status: .OK, text: "Cookie was set")
	response.cookies["test"] = "123"
	return response
}
```

The Status enum above (`.OK`) can be one of the following.

```swift
public enum Status {
    case OK, Created, Accepted
    case MovedPermanently
    case BadRequest, Unauthorized, Forbidden, NotFound
    case ServerError
    case Unknown
    case Custom(Int)
}
```

Or something custom.

```swift
let status: Status = .Custom(420) //https://dev.twitter.com/overview/api/response-codes
```

### Public

All files put in the `Public` folder at the root of your project will be available at the root of your domain. This is a great place to put your assets (`.css`, `.js`, `.png`, etc).

## Request

Every route call gets passed a `Request` object. This can be used to grab query and path parameters.

This is a list of the properties available on the request object.

```swift
let method: Method
var parameters: [String: String] //URL parameters like id in user/:id
var data: [String: String] //GET or POST data
var cookies: [String: String]
var session: Session
```

### Session

Sessions will be kept track of using the `vapor-session` cookie. The default (and currently only) session driver is `.Memory`.

```swift
if let name = request.session.data["name"] {
	//name was in session	
}

//store name in session
request.session.data["name"] = "Vapor"
```

## Controllers

Controllers are great for keeping your code organized. `Route` directives can take whole controllers or controller methods as arguments instead of closures.

`main.swift`
```swift
Route.get("heartbeat", closure: HeartbeatController().index)
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
Route.resource("user", controller: UserController()) 
```

This will create the appropriate `GET`, `POST`, `DELETE`, etc methods for individual and groups of users. 

## Bootstrap

Create a subclass of `Bootstrap` to hook into server requests and responses. Set the `server.boostrap` property to your subclass.

```swift
class MyBootstrap: Bootstrap {
	override func request(request: Request) {
		super.request(request)

		print("Incoming request from \(request.address)")
	}

	override func respond(request: Request, response: Response) {
		super.respond(request, response: response)

		print("Responding to request")
	}
}

server.bootstrap = MyBootstrap()
```

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

## Attributions

This project is based on [Swifter](https://github.com/glock45/swifter) by Damian Kołakowski. It uses compatibilty code from [NSLinux](https://github.com/johnno1962/NSLinux) by johnno1962.

Go checkout and star their repos.
