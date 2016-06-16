public protocol ResponseSerializer {
    init(stream: Stream)
    func serialize(_ response: Response) throws
}
