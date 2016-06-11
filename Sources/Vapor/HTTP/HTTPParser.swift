extension Array where Element: Hashable {
    /**
     This function is intended to be as performant as possible, which is part of the reason 
     why some of the underlying logic may seem a bit more tedious than is necessary
     */
    func trimmed(_ elements: [Element]) -> SubSequence {
        guard !isEmpty else { return [] }

        let lastIdx = self.count - 1
        var leadingIterator = self.indices.makeIterator()
        var trailingIterator = leadingIterator

        var leading = 0
        var trailing = lastIdx
        while let next = leadingIterator.next() where elements.contains(self[next]) {
            leading += 1
        }
        while let next = trailingIterator.next() where elements.contains(self[lastIdx - next]) {
            trailing -= 1
        }

        return self[leading...trailing]
    }
}


extension ArraySlice where Element: Hashable {
    /**
     This function is intended to be as performant as possible, which is part of the reason
     why some of the underlying logic may seem a bit more tedious than is necessary
     */
    func trimmed(_ elements: [Element]) -> SubSequence {
        guard !isEmpty else { return [] }

        let firstIdx = startIndex
        let lastIdx = endIndex - 1// self.count - 1

        var leadingIterator = self.indices.makeIterator()
        var trailingIterator = leadingIterator

        var leading = firstIdx
        var trailing = lastIdx
        while let next = leadingIterator.next() where elements.contains(self[next]) {
            leading += 1
        }
        while let next = trailingIterator.next() where elements.contains(self[lastIdx - next]) {
            trailing -= 1
        }

        return self[leading...trailing]
    }
}



// MARK: RObustness 

/*
 
 ******* ##################### **********
 *                                      *
 *                                      *
 *                                      *
 *            robustness                *
 *                                      *
 *                                      *
 *                                      *
 ******* ##################### **********

 3.5.  Message Parsing Robustness

 Older HTTP/1.0 user agent implementations might send an extra CRLF
 after a POST request as a workaround for some early server
 applications that failed to read message body content that was not
 terminated by a line-ending.  An HTTP/1.1 user agent MUST NOT preface
 or follow a request with an extra CRLF.  If terminating the request
 message body with a line-ending is desired, then the user agent MUST
 count the terminating CRLF octets as part of the message body length.

 In the interest of robustness, a server that is expecting to receive
 and parse a request-line SHOULD ignore at least one empty line (CRLF)
 received prior to the request-line.




 Fielding & Reschke           Standards Track                   [Page 34]

 RFC 7230           HTTP/1.1 Message Syntax and Routing         June 2014


 Although the line terminator for the start-line and header fields is
 the sequence CRLF, a recipient MAY recognize a single LF as a line
 terminator and ignore any preceding CR.

 Although the request-line and status-line grammar rules require that
 each of the component elements be separated by a single SP octet,
 recipients MAY instead parse on whitespace-delimited word boundaries
 and, aside from the CRLF terminator, treat any form of whitespace as
 the SP separator while ignoring preceding or trailing whitespace;
 such whitespace includes one or more of the following octets: SP,
 HTAB, VT (%x0B), FF (%x0C), or bare CR.  However, lenient parsing can
 result in security vulnerabilities if there are multiple recipients
 of the message and each has its own unique interpretation of
 robustness (see Section 9.5).

 When a server listening only for HTTP request messages, or processing
 what appears from the start-line to be an HTTP request message,
 receives a sequence of octets that does not match the HTTP-message
 grammar aside from the robustness exceptions listed above, the server
 SHOULD respond with a 400 (Bad Request) response.
 */

extension String: ErrorProtocol {}

