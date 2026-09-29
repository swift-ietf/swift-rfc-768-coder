public import Binary
public import Byte
public import RFC_768

extension RFC_768.Checksum: @retroactive Binary.Serializable {

    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ checksum: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == Byte {
        buffer.append(Byte(bitPattern: UInt8(checksum.rawValue >> 8)))
        buffer.append(Byte(bitPattern: UInt8(checksum.rawValue & 0xFF)))
    }
}
