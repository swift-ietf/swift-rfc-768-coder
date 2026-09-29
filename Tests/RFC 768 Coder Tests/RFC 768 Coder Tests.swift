import Binary
import Byte
import Coder
import Cursor
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
    @Suite struct `Pseudo Header Tests` {}
    @Suite struct `Datagram Tests` {}
    @Suite struct `Wire Vector Tests` {}
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
        #expect(try RFC_768.Port(8080).encoded() == bytes(0x1F, 0x90))
        #expect(try RFC_768.Port.dns.encoded() == bytes(0x00, 0x35))
    }

    @Test
    func `round-trips`() throws {
        let port = RFC_768.Port(50000)
        var input = try port.encoded()[...]
        #expect(try RFC_768.Port(decoding: &input) == port)
        #expect(input.isEmpty)
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

    @Test
    func `rejects a single byte and restores the cursor`() {
        var input = bytes(0x00)[...]
        #expect(throws: RFC_768.Length.Error.insufficientBytes) {
            try RFC_768.Length.coder.parse(&input)
        }
        #expect(input.count == 1)
    }

    @Test
    func `rejects empty input`() {
        var input = bytes()[...]
        #expect(throws: RFC_768.Length.Error.empty) {
            try RFC_768.Length.coder.parse(&input)
        }
    }

    @Test
    func `round-trips`() throws {
        let length = try RFC_768.Length(1500)
        #expect(try length.encoded() == bytes(0x05, 0xDC))

        var input = try length.encoded()[...]
        #expect(try RFC_768.Length(decoding: &input) == length)
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
    func `rejects a single byte and restores the cursor`() {
        var input = bytes(0xAB)[...]
        #expect(throws: RFC_768.Checksum.Error.insufficientBytes) {
            try RFC_768.Checksum.coder.parse(&input)
        }
        #expect(input.count == 1)
    }

    @Test
    func `rejects empty input`() {
        var input = bytes()[...]
        #expect(throws: RFC_768.Checksum.Error.empty) {
            try RFC_768.Checksum.coder.parse(&input)
        }
    }

    @Test
    func `round-trips`() throws {
        let checksum = RFC_768.Checksum(rawValue: 0xBD52)
        #expect(try checksum.encoded() == bytes(0xBD, 0x52))

        var input = try checksum.encoded()[...]
        #expect(try RFC_768.Checksum(decoding: &input) == checksum)
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

        #expect(checksummed.header.checksum.rawValue == 0xBD52)
        #expect(checksummed.data == datagram.data)

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

    @Test
    func `a corrupted payload no longer verifies`() throws {
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

        var pseudoBytes: [Byte] = []
        RFC_768.PseudoHeader.serialize(pseudoHeader, into: &pseudoBytes)

        var headerBytes: [Byte] = []
        RFC_768.Header.serialize(checksummed.header, into: &headerBytes)

        #expect(
            !RFC_768.Checksum.verify(
                pseudo: pseudoBytes,
                header: headerBytes,
                data: bytes(0xDE, 0xAD, 0xBE, 0xEE)
            )
        )
    }

    @Test
    func `an odd-length payload is padded with a zero octet`() throws {
        let datagram = try RFC_768.Datagram(
            source: .init(12345),
            destination: .dns,
            data: bytes(0xFF)
        )
        let pseudoHeader = RFC_768.PseudoHeader(
            source: try .init("10.0.0.1"),
            destination: try .init("10.0.0.2"),
            length: datagram.header.length.rawValue
        )

        #expect(datagram.withChecksum(pseudo: pseudoHeader).header.checksum.rawValue == 0xBC6A)
    }

    @Test
    func `a checksum that computes to zero is sent as all ones`() throws {
        let datagram = try RFC_768.Datagram(
            source: .init(12345),
            destination: .dns,
            data: bytes(0xBB, 0x69)
        )
        let pseudoHeader = RFC_768.PseudoHeader(
            source: try .init("10.0.0.1"),
            destination: try .init("10.0.0.2"),
            length: datagram.header.length.rawValue
        )

        let checksummed = datagram.withChecksum(pseudo: pseudoHeader)

        #expect(checksummed.header.checksum.rawValue == 0xFFFF)
        #expect(!checksummed.header.checksum.isAbsent)
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
        #expect(input.isEmpty)
    }

    @Test
    func `writes the eight header bytes`() throws {
        let header = RFC_768.Header(
            source: .init(12345),
            destination: .dns,
            length: try .init(20),
            checksum: RFC_768.Checksum(rawValue: 0xABCD)
        )
        #expect(try header.encoded() == bytes(0x30, 0x39, 0x00, 0x35, 0x00, 0x14, 0xAB, 0xCD))
    }

    @Test
    func `round-trips a header through bytes`() throws {
        let original = RFC_768.Header(
            source: .init(8080),
            destination: .ntp,
            length: try .init(16),
            checksum: RFC_768.Checksum(rawValue: 0xABCD)
        )

        var input = try original.encoded()[...]
        #expect(try RFC_768.Header(decoding: &input) == original)
    }

    @Test
    func `reports which field rejected the bytes`() {
        var input = bytes(0x30, 0x39, 0x00, 0x35, 0x00, 0x07, 0x00, 0x00)[...]
        #expect(throws: RFC_768.Header.Error.length(.tooShort(7))) {
            try RFC_768.Header.coder.parse(&input)
        }
        #expect(input.count == 8)
    }

    @Test
    func `rejects empty input as a missing source port`() {
        var input = bytes()[...]
        #expect(throws: RFC_768.Header.Error.source(.empty)) {
            try RFC_768.Header.coder.parse(&input)
        }
    }

    @Test
    func `rejects a truncated header and restores the cursor`() {
        var input = bytes(0x30, 0x39, 0x00, 0x35, 0x00)[...]
        #expect(throws: RFC_768.Header.Error.length(.insufficientBytes)) {
            try RFC_768.Header.coder.parse(&input)
        }
        #expect(input.count == 5)
    }
}

extension `RFC 768 Coder Tests`.`Pseudo Header Tests` {

    @Test
    func `writes the addresses, a zero octet, the protocol number and the length`() throws {
        let pseudoHeader = RFC_768.PseudoHeader(
            source: try .init("192.168.1.1"),
            destination: try .init("192.168.1.2"),
            length: 12
        )

        var buffer: [Byte] = []
        RFC_768.PseudoHeader.serialize(pseudoHeader, into: &buffer)

        #expect(
            buffer == bytes(
                0xC0, 0xA8, 0x01, 0x01,
                0xC0, 0xA8, 0x01, 0x02,
                0x00, 0x11,
                0x00, 0x0C
            )
        )
    }
}

extension `RFC 768 Coder Tests`.`Datagram Tests` {

    @Test
    func `writes the header then the payload`() throws {
        let datagram = try RFC_768.Datagram(
            source: .init(8080),
            destination: .syslog,
            data: bytes(0xDE, 0xAD, 0xBE, 0xEF)
        )
        #expect(
            try datagram.encoded() == bytes(
                0x1F, 0x90,
                0x02, 0x02,
                0x00, 0x0C,
                0x00, 0x00,
                0xDE, 0xAD, 0xBE, 0xEF
            )
        )
    }

    @Test
    func `round-trips a datagram through bytes`() throws {
        let original = try RFC_768.Datagram(
            source: .init(8080),
            destination: .syslog,
            data: bytes(0xDE, 0xAD, 0xBE, 0xEF)
        )

        var input = try original.encoded()[...]
        #expect(try RFC_768.Datagram(decoding: &input) == original)
        #expect(input.isEmpty)
    }

    @Test
    func `stops after the length the header declares`() throws {
        var input = bytes(
            0x1F, 0x90, 0x02, 0x02, 0x00, 0x0A, 0x00, 0x00,
            0xDE, 0xAD,
            0xBE, 0xEF
        )[...]
        let datagram = try RFC_768.Datagram.coder.parse(&input)
        #expect(datagram.data == bytes(0xDE, 0xAD))
        #expect(input == bytes(0xBE, 0xEF)[...])
    }

    @Test
    func `reads a datagram without a payload`() throws {
        var input = bytes(0x00, 0x35, 0x30, 0x39, 0x00, 0x08, 0x00, 0x00)[...]
        let datagram = try RFC_768.Datagram.coder.parse(&input)
        #expect(datagram.header.source == .dns)
        #expect(datagram.data.isEmpty)
    }

    @Test
    func `rejects a datagram whose payload is short and restores the cursor`() throws {
        let original = try RFC_768.Datagram(
            source: .init(8080),
            destination: .syslog,
            data: bytes(0xDE, 0xAD, 0xBE, 0xEF)
        )

        var buffer = try original.encoded()
        buffer.removeLast(2)

        var input = buffer[...]
        #expect(throws: RFC_768.Datagram.Error.insufficientData(expected: 4, got: 2)) {
            try RFC_768.Datagram.coder.parse(&input)
        }
        #expect(input.count == buffer.count)
    }

    @Test
    func `rejects a bad header and restores the cursor`() {
        var input = bytes(0x1F, 0x90, 0x02, 0x02, 0x00, 0x07, 0x00, 0x00, 0xFF)[...]
        #expect(throws: RFC_768.Datagram.Error.header(.length(.tooShort(7)))) {
            try RFC_768.Datagram.coder.parse(&input)
        }
        #expect(input.count == 9)
    }

    @Test
    func `rejects empty input`() {
        var input = bytes()[...]
        #expect(throws: RFC_768.Datagram.Error.header(.source(.empty))) {
            try RFC_768.Datagram.coder.parse(&input)
        }
    }
}

extension `RFC 768 Coder Tests`.`Wire Vector Tests` {

    @Test
    func `a name-service query from 10.0.0.1 to 10.0.0.2`() throws {
        let wire = bytes(
            0x30, 0x39,
            0x00, 0x35,
            0x00, 0x0C,
            0xBB, 0x64,
            0x00, 0x01, 0x00, 0x00
        )

        var input = wire[...]
        let datagram = try RFC_768.Datagram.coder.parse(&input)
        #expect(datagram.header.source.rawValue == 12345)
        #expect(datagram.header.destination == .dns)
        #expect(datagram.header.length.rawValue == 12)
        #expect(datagram.header.checksum.rawValue == 0xBB64)
        #expect(datagram.data == bytes(0x00, 0x01, 0x00, 0x00))
        #expect(input.isEmpty)

        let pseudoHeader = RFC_768.PseudoHeader(
            source: try .init("10.0.0.1"),
            destination: try .init("10.0.0.2"),
            length: datagram.header.length.rawValue
        )
        #expect(datagram.withChecksum(pseudo: pseudoHeader) == datagram)
        #expect(try datagram.encoded() == wire)
    }

    @Test
    func `a syslog datagram from 192.168.1.1 to 192.168.1.2`() throws {
        let wire = bytes(
            0x1F, 0x90,
            0x02, 0x02,
            0x00, 0x0C,
            0xBD, 0x52,
            0xDE, 0xAD, 0xBE, 0xEF
        )

        var input = wire[...]
        let datagram = try RFC_768.Datagram(decoding: &input)

        let pseudoHeader = RFC_768.PseudoHeader(
            source: try .init("192.168.1.1"),
            destination: try .init("192.168.1.2"),
            length: datagram.header.length.rawValue
        )

        var pseudoBytes: [Byte] = []
        RFC_768.PseudoHeader.serialize(pseudoHeader, into: &pseudoBytes)

        var headerBytes: [Byte] = []
        RFC_768.Header.serialize(datagram.header, into: &headerBytes)

        #expect(RFC_768.Checksum.verify(pseudo: pseudoBytes, header: headerBytes, data: datagram.data))
        #expect(try datagram.encoded() == wire)
    }
}
