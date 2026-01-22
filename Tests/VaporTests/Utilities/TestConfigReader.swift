import Configuration

let testConfigReader: ConfigReader = {
    ConfigReader(
        providers: [
            EnvironmentVariablesProvider(),
            InMemoryProvider(values: ["log.level": "debug"]),
        ]
    )
}()