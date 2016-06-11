extension Version {
    /**
        HTTP uses a "<major>.<minor>" numbering scheme to indicate versions
        of the protocol. The protocol versioning policy is intended to allow
        the sender to indicate the format of a message and its capacity for
        understanding further HTTP communication, rather than the features
        obtained via that communication. No change is made to the version
        number for the addition of message components which do not affect
        communication behavior or which only add to extensible field values.
        The <minor> number is incremented when the changes made to the
        protocol add features which do not change the general message parsing
        algorithm, but which may add to the message semantics and imply
        additional capabilities of the sender. The <major> number is
        incremented when the format of a message within the protocol is
        changed. See RFC 2145 [36] for a fuller explanation.

        The version of an HTTP message is indicated by an HTTP-Version field
        in the first line of the message.

        HTTP-Version   = "HTTP" "/" 1*DIGIT "." 1*DIGIT
    */
    init(_ bytes: BytesSlice) {
        // ["HTTP", "1.1"]
        let comps = bytes.split(separator: .forwardSlash, maxSplits: 1)

        var major = 0
        var minor = 0

        if comps.count == 2 {
            // ["1", "1"]
            let version = comps[1].split(separator: .period, maxSplits: 1)

            major = version[0].int

            if version.count == 2 {
                minor = version[1].int
            }
        }

        self = Version(major: major, minor: minor)
    }
}
