extension Cookies {
    func serialize() -> Data? {
        let cookies = self.map { cookie in
            return "\(cookie.name)=\(cookie.value)"
        }

        if cookies.count >= 1 {
            return cookies.joined(separator: ";").data
        }

        return nil
    }
}
