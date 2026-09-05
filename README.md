# swift-rfc-768-coder

Wire coders for [swift-rfc-768](https://github.com/swift-ietf/swift-rfc-768): the UDP port, length, checksum, header and datagram each get a `<Type>.Coder` over a byte cursor (the field's network-order octets) and a `Binary.Serializable` conformance, together with the RFC 768 pseudo-header serialization and the one's-complement checksum computation; the domain package stays a pure model.
