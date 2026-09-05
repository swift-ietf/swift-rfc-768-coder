public import Byte
public import RFC_768

extension RFC_768.Checksum {

    public static func compute<P, H, D>(
        pseudo pseudoHeader: P,
        header udpHeader: H,
        data: D
    ) -> RFC_768.Checksum
    where
        P: Swift.Collection,
        P.Element == Byte,
        H: Swift.Collection,
        H.Element == Byte,
        D: Swift.Collection,
        D.Element == Byte
    {
        var sum: UInt32 = 0

        sum = sumWords(sum, bytes: pseudoHeader)
        sum = sumWords(sum, bytes: udpHeader)
        sum = sumWords(sum, bytes: data)

        while sum > 0xFFFF {
            sum = (sum & 0xFFFF) + (sum >> 16)
        }

        var checksum = UInt16(~sum & 0xFFFF)

        if checksum == 0 {
            checksum = 0xFFFF
        }

        return RFC_768.Checksum(rawValue: checksum)
    }

    private static func sumWords<Bytes: Swift.Collection>(
        _ initial: UInt32,
        bytes: Bytes
    ) -> UInt32 where Bytes.Element == Byte {
        var sum = initial
        var iterator = bytes.makeIterator()

        while let high = iterator.next() {
            let low = iterator.next()?.bitPattern ?? 0
            sum += UInt32(high.bitPattern) << 8 | UInt32(low)
        }

        return sum
    }

    public static func verify<P, H, D>(
        pseudo pseudoHeader: P,
        header udpHeader: H,
        data: D
    ) -> Bool
    where
        P: Swift.Collection,
        P.Element == Byte,
        H: Swift.Collection,
        H.Element == Byte,
        D: Swift.Collection,
        D.Element == Byte
    {
        var sum: UInt32 = 0
        sum = sumWords(sum, bytes: pseudoHeader)
        sum = sumWords(sum, bytes: udpHeader)
        sum = sumWords(sum, bytes: data)

        while sum > 0xFFFF {
            sum = (sum & 0xFFFF) + (sum >> 16)
        }

        return sum == 0xFFFF
    }
}
