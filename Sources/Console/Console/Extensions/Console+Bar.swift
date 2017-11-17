extension Console {
    /// Creates a progress bar using the console.
    public func progressBar(
        title: String = "",
        width: Int = 25,
        barStyle: ConsoleStyle = .info,
        titleStyle: ConsoleStyle = .plain,
        animated: Bool = true
    ) -> ProgressBar {
        return ProgressBar(
            console: self,
            title: title,
            width: width,
            barStyle: barStyle,
            titleStyle: titleStyle,
            animated: animated
        )
    }
    
    /// Creates a LoadingBar using the console.
    public func loadingBar(
        title: String = "",
        width: Int = 25,
        barStyle: ConsoleStyle = .info,
        titleStyle: ConsoleStyle = .plain,
        animated: Bool = true
    ) -> LoadingBar {
        return LoadingBar(
            console: self,
            title: title,
            width: width,
            barStyle: barStyle,
            titleStyle: titleStyle,
            animated: animated
        )
    }
}
