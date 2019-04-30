extension Response {
    struct BodyStream {
        let count: Int
        let callback: (BodyStreamWriter) -> ()
    }
}
