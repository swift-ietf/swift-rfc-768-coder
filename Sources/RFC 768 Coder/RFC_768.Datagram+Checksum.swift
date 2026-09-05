public import Byte
public import RFC_768
import Binary_Serializable

extension RFC_768.Datagram {

    public func withChecksum(
        pseudo pseudoHeader: RFC_768.PseudoHeader
    ) -> RFC_768.Datagram {

        var headerBytes: [Byte] = []
        let unchecksummedHeader = RFC_768.Header(
            source: header.source,
            destination: header.destination,
            length: header.length,
            checksum: .zero
        )
        RFC_768.Header.serialize(unchecksummedHeader, into: &headerBytes)

        var pseudoBytes: [Byte] = []
        RFC_768.PseudoHeader.serialize(pseudoHeader, into: &pseudoBytes)

        let checksum = RFC_768.Checksum.compute(
            pseudo: pseudoBytes,
            header: headerBytes,
            data: data
        )

        return RFC_768.Datagram(
            header: RFC_768.Header(
                source: header.source,
                destination: header.destination,
                length: header.length,
                checksum: checksum
            ),
            data: data
        )
    }
}
