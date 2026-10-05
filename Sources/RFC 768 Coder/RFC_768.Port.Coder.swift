public import Byte
public import Coder
public import Cursor
public import RFC_768
import Binary
import Parser
import Serializer

extension RFC_768.Port {

    public struct Coder<Input: Cursor.`Protocol`<Byte, Never>, Buffer: RangeReplaceableCollection<Byte>>: Coding {
        public var body: Never {
            borrowing get {
                return fatalError("\(Self.self) is a leaf coder: implement parse and serialize directly")
            }
        }


        public typealias Output = RFC_768.Port

        public typealias Failure = RFC_768.Port.Error

        public init() {}

        public borrowing func parse(_ input: inout Input) throws(Failure) -> Output {
            let start = input.checkpoint
            guard let high = input.next() else {
                throw .empty
            }
            guard let low = input.next() else {
                input.seek(to: start)
                throw .insufficientBytes
            }
            return RFC_768.Port(rawValue: UInt16(high.bitPattern) << 8 | UInt16(low.bitPattern))
        }

        public borrowing func serialize(_ output: Output, into buffer: inout Buffer) throws(Failure) {
            RFC_768.Port.serialize(output, into: &buffer)
        }
    }

    public static var coder: Coder<ArraySlice<Byte>, [Byte]> { .init() }
}
