import Core

class ResultStream<Result> : Stream {
    typealias Input = Result?
    typealias Output = Result
    
    func inputStream(_ input: Input) {
        if let input = input {
            outputStream?(input)
        } else {
            complete()
        }
    }
    
    init(_ complete: @escaping (()->())) {
        self.complete = complete
    }
    
    var complete: (()->())
    
    var outputStream: OutputHandler?
    var errorStream: ErrorHandler?
}
