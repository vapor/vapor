/*

 // MARK: Fragmentation

 The following rules apply to fragmentation:

 o  An unfragmented message consists of a single frame with the FIN
 bit set (Section 5.2) and an opcode other than 0.

 o  A fragmented message consists of a single frame with the FIN bit
 clear and an opcode other than 0, followed by zero or more frames
 with the FIN bit clear and the opcode set to 0, and terminated by
 a single frame with the FIN bit set and an opcode of 0.  A
 fragmented message is conceptually equivalent to a single larger
 message whose payload is equal to the concatenation of the
 payloads of the fragments in order; however, in the presence of
 extensions, this may not hold true as the extension defines the
 interpretation of the "Extension data" present.  For instance,
 "Extension data" may only be present at the beginning of the first
 fragment and apply to subsequent fragments, or there may be
 "Extension data" present in each of the fragments that applies
 only to that particular fragment.  In the absence of "Extension
 data", the following example demonstrates how fragmentation works.

 EXAMPLE: For a text message sent as three fragments, the first
 fragment would have an opcode of 0x1 and a FIN bit clear, the
 second fragment would have an opcode of 0x0 and a FIN bit clear,
 and the third fragment would have an opcode of 0x0 and a FIN bit
 that is set.

 o  Control frames (see Section 5.5) MAY be injected in the middle of
 a fragmented message.  Control frames themselves MUST NOT be
 fragmented.

 o  Message fragments MUST be delivered to the recipient in the order
 sent by the sender.

 o  The fragments of one message MUST NOT be interleaved between the
 fragments of another message unless an extension has been
 negotiated that can interpret the interleaving.

 o  An endpoint MUST be capable of handling control frames in the
 middle of a fragmented message.

 o  A sender MAY create fragments of any size for non-control
 messages.

 o  Clients and servers MUST support receiving both fragmented and
 unfragmented messages.

 o  As control frames cannot be fragmented, an intermediary MUST NOT
 attempt to change the fragmentation of a control frame.

 o  An intermediary MUST NOT change the fragmentation of a message if
 any reserved bit values are used and the meaning of these values
 is not known to the intermediary.

 o  An intermediary MUST NOT change the fragmentation of any message
 in the context of a connection where extensions have been
 negotiated and the intermediary is not aware of the semantics of
 the negotiated extensions.  Similarly, an intermediary that didn't
 see the WebSocket handshake (and wasn't notified about its
 content) that resulted in a WebSocket connection MUST NOT change
 the fragmentation of any message of such connection.

 o  As a consequence of these rules, all fragments of a message are of
 the same type, as set by the first fragment's opcode.  Since
 control frames cannot be fragmented, the type for all fragments in
 a message MUST be either text, binary, or one of the reserved
 opcodes.
 */
