extension Connection {
    
    
    /// Handles the incoming packet with the default handler
    ///
    /// Handles the packet for the handshake
    internal func handlePacket(_ packet: Packet) {
        if authenticated.future.isCompleted {
            return
        }
        
        if let ssl = ssl {
            guard sslSettingsSent else {
                do {
                    try self.upgradeSSL(for: packet, using: ssl)
                } catch {
                    self.authenticated.fail(error)
                    self.close()
                }
                
                return
            }
        }
        
        guard self.handshake != nil else {
            self.doHandshake(for: packet)
            return
        }
        
        finishAuthentication(for: packet, completing: authenticated)
    }
    
    func upgradeSSL(for packet: Packet, using config: MySQLSSLConfig) throws {
        let handshake = try packet.parseHandshake()
        self.handshake = handshake
        
        var data = Data(repeating: 0, count: 32)
        
        data.withUnsafeMutableBytes { (pointer: MutableBytesPointer) in
            let combinedCapabilities = self.capabilities.rawValue & handshake.capabilities.rawValue
            
            memcpy(pointer, [
                UInt8((combinedCapabilities) & 0xff),
                UInt8((combinedCapabilities >> 1) & 0xff),
                UInt8((combinedCapabilities >> 2) & 0xff),
                UInt8((combinedCapabilities >> 3) & 0xff),
            ], 4)
            
            pointer.advanced(by: 8).pointee = handshake.defaultCollation
            
            // the rest is reserved
        }
        
        try data.withByteBuffer { buffer in
            try self.write(packetFor: buffer)
        }
        
        let ssl = try config.client.init(tcp: self.client, using: config.settings).socket
        try ssl.prepareSocket()
        self.socket = ssl
        fatalError()
        //        ssl.stream(to: parser)
        //        try config. .upgrade(
        //            socket: self.socket.socket,
        //            settings: config.settings,
        //            eventLoop: self.socket.eventLoop
        //        ).map { client in
        //            client.stream(to: self.parser)
        //            self.socketWrite = client.onInput
        //
        //            try self.sendHandshake()
        //        }.catch(self.authenticated.fail)
    }
    
    /// Writes a packet's payload data to the socket
    func write(packetFor data: Data, startingAt start: UInt8 = 0) throws {
        try data.withUnsafeBytes { (pointer: BytesPointer) in
            let buffer = ByteBuffer(start: pointer, count: data.count)
            
            try write(packetFor: buffer)
        }
    }
    
    /// Writes a packet's payload buffer to the socket
    func write(packetFor data: ByteBuffer, startingAt start: UInt8 = 0) throws {
        var offset = 0
        
        guard let input = data.baseAddress else {
            throw MySQLError(.invalidPacket)
        }
        
        // Starts the packet number at the starting number
        // The handshake starts at 1, instead of 0
        var packetNumber: UInt8 = start
        
        // Splits the paylad into packets
        while offset < data.count {
            defer {
                packetNumber = packetNumber &+ 1
            }
            
            let dataSize = min(Packet.maxPayloadSize, data.count &- offset)
            let packetSize = UInt32(dataSize)
            
            let packetSizeBytes = [
                UInt8((packetSize) & 0xff),
                UInt8((packetSize >> 8) & 0xff),
                UInt8((packetSize >> 16) & 0xff),
                ]
            
            defer {
                offset = offset + dataSize
            }
            
            memcpy(self.writeBuffer, packetSizeBytes, 3)
            self.writeBuffer[3] = packetNumber
            memcpy(self.writeBuffer.advanced(by: 4), input.advanced(by: offset), dataSize)
            
            let buffer = ByteBuffer(start: self.writeBuffer, count: dataSize &+ 4)
            _ = try self.socketWrite(buffer)
        }
        
        return
    }
}
