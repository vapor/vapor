import Configuration

let testConfigReader: ConfigReader = {
    ConfigReader(
        providers: [
            EnvironmentVariablesProvider()
        ]
    )
}()
