public protocol StreamSerializer {
    init(stream: Stream)
    func serialize(_ response: Response) throws
}
