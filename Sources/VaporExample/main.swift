let app = Application()

app.get("test") { request in
    return "123"
}

app.start(port: 8080)
