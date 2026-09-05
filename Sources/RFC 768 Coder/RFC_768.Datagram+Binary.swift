public import Binary_Serializable
public import Byte
public import RFC_768

extension RFC_768.Datagram: @retroactive Binary.Serializable {

    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ datagram: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == Byte {
        RFC_768.Header.serialize(datagram.header, into: &buffer)
        buffer.append(contentsOf: datagram.data)
    }
}
