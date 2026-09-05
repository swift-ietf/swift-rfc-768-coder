public import Binary_Serializable
public import Byte
public import RFC_768

extension RFC_768.Header: @retroactive Binary.Serializable {

    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ header: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == Byte {
        RFC_768.Port.serialize(header.source, into: &buffer)
        RFC_768.Port.serialize(header.destination, into: &buffer)
        RFC_768.Length.serialize(header.length, into: &buffer)
        RFC_768.Checksum.serialize(header.checksum, into: &buffer)
    }
}
