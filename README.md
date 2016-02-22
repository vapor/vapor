![Vapor](https://cloud.githubusercontent.com/assets/1342803/12457900/1825c70c-bf75-11e5-9080-989345fa43e2.png)

# Vapor

A Laravel/Lumen Inspired Web Framework for Swift that works on iOS, OS X, and Ubuntu.

- [x] Insanely fast
- [x] Beautiful syntax
- [x] Type safe

## Badges

[![Build Status](https://img.shields.io/travis/qutheory/vapor.svg?style=flat-square)](https://travis-ci.org/qutheory/vapor)
[![Issue Stats](http://issuestats.com/github/qutheory/vapor/badge/pr?style=flat-square)](http://issuestats.com/github/qutheory/vapor)
[![PRs Welcome](https://img.shields.io/badge/prs-welcome-brightgreen.svg?style=flat-square)](http://makeapullrequest.com)
[![Slack Status](http://slack.tanner.xyz:8085/badge.svg?style=flat-square)](http://slack.tanner.xyz:8085)

## Work in Progress

This is a work in progress, so *do not* rely on this for anything important. And pull requests are welcome!

## Documentation

Visit the [Vapor Wiki](https://github.com/qutheory/vapor/wiki) for extensive documentation on getting setup, using, and contributing to Vapor.

## Application

Starting the application takes two lines.

`main.swift`
```swift
import Vapor

let app = Application()
app.start()
```

You can also choose which port the server runs on.

```swift
app.start(port: 8080)
```

If you are having trouble connecting, make sure your ports are open. Check out `apt-get ufw` for simple port management.

## Routing

Routing in Vapor is simple and very similar to Laravel.

`main.swift`
```swift
app.get("welcome") { request in
	return "Hello"
}

//...start application
```

Here we will respond to all requests to `http://example.com/welcome` with the string `"Hello"`.

### JSON

Responding with JSON is easy.

```swift
app.get("version") { request in
	return ["version": "1.0"]
}
```

This responds to all requests to `http://example.com/version` with the JSON dictionary `{"version": "1.0"}` and `Content-Type: application/json`.

### Views

You can also respond with HTML pages.

```swift
app.get("/") { request in
	return View(path: "index.html")
}
```

Or [Stencil](https://github.com/kylef/Stencil) templates.

`index.stencil`

```mustache
<html>
	<h1>{{ message }}</h1>
</html>
```

```swift
app.get("/") { request in
	return View(path: "index.stencil", context: ["message": "Hello"])
}
```

If you have `VaporStencil` added, just put the View file in the `Resources` folder at the root of your project and it will be served.

#### Stencil

To add `VaporStencil`, add the following package to your `Package.swift`.

`Package.swift`
```swift
.Package(url: "https://github.com/qutheory/vapor-stencil.git", majorVersion: 0)
```

Then set the `StencilRenderer()` on your `View.renderers` for whatever file extensions you would like to be rendered as `Stencil` templates.

`main.swift`
```swift
import VaporStencil

//set the stencil renderer
//for all .stencil files
View.renderers[".stencil"] = StencilRenderer()
```

### Response

A manual response can be returned if you want to set something like `cookies`.

```swift
app.get("cookie") { request in
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

### Data

To access JSON, Query, and form-encoded data from the `Request`.

```swift
app.post("hello") { request in
	guard let name = request.data["name"]?.string {
		return "Please include a name"
	}

	return "Hello, \(name)!"
}
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

## Database

Vapor was designed alongside [Fluent](https://github.com/qutheory/fluent), an Eloquent inspired ORM that empowers simple and expressive database management.

```swift
import Fluent

if let user = User.find(5) {
    print("Found \(user.name)")

    user.name = "New Name"
    user.save()
}
```

Underlying [Fluent](https://github.com/qutheory/fluent) is a powerful Query builder.

```swift
let user = Query<User>().filter("id", notIn: [1, 2, 3]).filter("age", .GreaterThan, 21).first
```

## Controllers

Controllers are great for keeping your code organized. `Route` directives can take whole controllers or controller methods as arguments instead of closures.

`main.swift`
```swift
app.get("heartbeat", closure: HeartbeatController().index)
```

To pass a function name as a closure like above, the closure must have the function signature

```swift
func index(request: Request) -> ResponseConvertible
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
app.resource("user", controller: UserController())
```

This will create the appropriate `GET`, `POST`, `DELETE`, etc methods for individual and groups of users:

- .Get /user - an index of users
- .Get /user/:id - a single user etc

## Middleware

Create a class conforming to `Middleware` to hook into server requests and responses. Append your classes to the `server.middleware` array in the order you want them to run..

```swift
class MyMiddleware: Middleware {
    func handle(handler: Request -> Response) -> (Request -> Response) {
        return { request in
            print("Incoming request from \(request.address)")

            let response = handler(request)

            print("Responding with status \(response.status)")

            return response
        }
    }
}

server.middleware.append(MyMiddleware
```

My website `http://tanner.xyz` is currently running using Vapor.

## Attributions

This project is based on [Swifter](https://github.com/glock45/swifter) by Damian Kołakowski. It uses compatibility code from [NSLinux](https://github.com/johnno1962/NSLinux) by johnno1962.

Go checkout and star their repos.
