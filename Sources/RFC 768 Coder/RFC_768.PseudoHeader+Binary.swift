public import Binary
public import Byte
public import RFC_768
import RFC_791
import RFC_791_Coder

extension RFC_768.PseudoHeader: @retroactive Binary.Serializable {

    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ pseudoHeader: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == Byte {
        RFC_791.IPv4.Address.serialize(pseudoHeader.source, into: &buffer)
        RFC_791.IPv4.Address.serialize(pseudoHeader.destination, into: &buffer)

        buffer.append(Byte(bitPattern: 0))
        RFC_791.`Protocol`.serialize(RFC_768.protocolNumber, into: &buffer)

        buffer.append(Byte(bitPattern: UInt8(pseudoHeader.length >> 8)))
        buffer.append(Byte(bitPattern: UInt8(pseudoHeader.length & 0xFF)))
    }
}
