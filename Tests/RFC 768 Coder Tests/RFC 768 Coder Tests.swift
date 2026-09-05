import Binary_Serializable
import Byte
import Byte_Standard_Library_Integration
import Coder
import Coder_Standard_Library_Integration
import Cursor_Standard_Library_Integration
import Parser
import RFC_768
import RFC_768_Coder
import RFC_791
import Serializer
import Testing

@Suite
struct `RFC 768 Coder Tests` {
    @Suite struct `Port Tests` {}
    @Suite struct `Length Tests` {}
    @Suite struct `Checksum Tests` {}
    @Suite struct `Header Tests` {}
    @Suite struct `Datagram Tests` {}
}

func bytes(_ values: UInt8...) -> [Byte] {
    values.map(Byte.init(bitPattern:))
}

extension `RFC 768 Coder Tests`.`Port Tests` {

    @Test
    func `reads two network-order bytes and stops`() throws {
        var input = bytes(0x1F, 0x90, 0xFF)[...]
        let port = try RFC_768.Port.coder.parse(&input)
        #expect(port.rawValue == 8080)
        #expect(input == bytes(0xFF)[...])
    }

    @Test
    func `rejects empty input`() {
        var input = bytes()[...]
        #expect(throws: RFC_768.Port.Error.empty) {
            try RFC_768.Port.coder.parse(&input)
        }
    }

    @Test
    func `rejects a single byte and restores the cursor`() {
        var input = bytes(0x1F)[...]
        #expect(throws: RFC_768.Port.Error.insufficientBytes) {
            try RFC_768.Port.coder.parse(&input)
        }
        #expect(input.count == 1)
    }

    @Test
    func `writes two network-order bytes`() throws {
        var buffer: [Byte] = []
        try RFC_768.Port(8080).encode(into: &buffer)
        #expect(buffer == bytes(0x1F, 0x90))
    }
}

extension `RFC 768 Coder Tests`.`Length Tests` {

    @Test
    func `reads a length that covers the header`() throws {
        var input = bytes(0x00, 0x14)[...]
        let length = try RFC_768.Length.coder.parse(&input)
        #expect(length.rawValue == 20)
        #expect(length.data == 12)
    }

    @Test
    func `rejects a length below the header size and restores the cursor`() {
        var input = bytes(0x00, 0x07)[...]
        #expect(throws: RFC_768.Length.Error.tooShort(7)) {
            try RFC_768.Length.coder.parse(&input)
        }
        #expect(input.count == 2)
    }
}

extension `RFC 768 Coder Tests`.`Checksum Tests` {

    @Test
    func `reads two network-order bytes`() throws {
        var input = bytes(0xAB, 0xCD)[...]
        let checksum = try RFC_768.Checksum.coder.parse(&input)
        #expect(checksum.rawValue == 0xABCD)
    }

    @Test
    func `computes the checksum a receiver verifies`() throws {
        let datagram = try RFC_768.Datagram(
            source: .init(8080),
            destination: .syslog,
            data: bytes(0xDE, 0xAD, 0xBE, 0xEF)
        )
        let pseudoHeader = RFC_768.PseudoHeader(
            source: try .init("192.168.1.1"),
            destination: try .init("192.168.1.2"),
            length: datagram.header.length.rawValue
        )

        let checksummed = datagram.withChecksum(pseudo: pseudoHeader)

        #expect(!checksummed.header.checksum.isAbsent)

        var pseudoBytes: [Byte] = []
        RFC_768.PseudoHeader.serialize(pseudoHeader, into: &pseudoBytes)

        var headerBytes: [Byte] = []
        RFC_768.Header.serialize(checksummed.header, into: &headerBytes)

        #expect(
            RFC_768.Checksum.verify(
                pseudo: pseudoBytes,
                header: headerBytes,
                data: checksummed.data
            )
        )
    }
}

extension `RFC 768 Coder Tests`.`Header Tests` {

    @Test
    func `reads the eight header bytes`() throws {
        var input = bytes(
            0x30, 0x39,
            0x00, 0x35,
            0x00, 0x14,
            0x00, 0x00
        )[...]
        let header = try RFC_768.Header.coder.parse(&input)
        #expect(header.source.rawValue == 12345)
        #expect(header.destination == .dns)
        #expect(header.length.rawValue == 20)
        #expect(header.checksum.isAbsent)
    }

    @Test
    func `round-trips a header through bytes`() throws {
        let original = RFC_768.Header(
            source: .init(8080),
            destination: .ntp,
            length: try .init(16),
            checksum: RFC_768.Checksum(rawValue: 0xABCD)
        )

        var buffer: [Byte] = []
        try original.encode(into: &buffer)

        var input = buffer[...]
        #expect(try RFC_768.Header.coder.parse(&input) == original)
    }

    @Test
    func `reports which field rejected the bytes`() {
        var input = bytes(0x30, 0x39, 0x00, 0x35, 0x00, 0x07, 0x00, 0x00)[...]
        #expect(throws: RFC_768.Header.Error.length(.tooShort(7))) {
            try RFC_768.Header.coder.parse(&input)
        }
    }
}

extension `RFC 768 Coder Tests`.`Datagram Tests` {

    @Test
    func `round-trips a datagram through bytes`() throws {
        let original = try RFC_768.Datagram(
            source: .init(8080),
            destination: .syslog,
            data: bytes(0xDE, 0xAD, 0xBE, 0xEF)
        )

        var buffer: [Byte] = []
        try original.encode(into: &buffer)

        var input = buffer[...]
        #expect(try RFC_768.Datagram.coder.parse(&input) == original)
    }

    @Test
    func `rejects a datagram whose payload is short and restores the cursor`() throws {
        let original = try RFC_768.Datagram(
            source: .init(8080),
            destination: .syslog,
            data: bytes(0xDE, 0xAD, 0xBE, 0xEF)
        )

        var buffer: [Byte] = []
        try original.encode(into: &buffer)
        buffer.removeLast(2)

        var input = buffer[...]
        #expect(throws: RFC_768.Datagram.Error.insufficientData(expected: 4, got: 2)) {
            try RFC_768.Datagram.coder.parse(&input)
        }
        #expect(input.count == buffer.count)
    }
}
