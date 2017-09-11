////
//class ResultStream<Result> : InputStream {
//    typealias Input = Result
//    
//    func inputStream(_ input: Input) {
//        if let input = input {
//            outputStream?(input)
//        } else {
//            complete()
//        }
//    }
//    
//    init(_ complete: @escaping (()->())) {
//        self.complete = complete
//    }
//    
//    var complete: (()->())
//    
//    var outputStream: OutputHandler?
//    var errorStream: ErrorHandler?
//}

