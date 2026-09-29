public import Byte
public import Coder
public import Cursor
public import RFC_768
import Binary
import Parser
import Serializer

extension RFC_768.Length {

    public struct Coder<Input: Cursor.`Protocol`<Byte, Never>, Buffer: RangeReplaceableCollection<Byte>>: Coding {

        public typealias Output = RFC_768.Length

        public typealias Failure = RFC_768.Length.Error

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
            let value = UInt16(high.bitPattern) << 8 | UInt16(low.bitPattern)
            do throws(RFC_768.Length.Error) {
                return try RFC_768.Length(rawValue: value)
            } catch {
                input.seek(to: start)
                throw error
            }
        }

        public borrowing func serialize(_ output: Output, into buffer: inout Buffer) throws(Failure) {
            RFC_768.Length.serialize(output, into: &buffer)
        }
    }

    public static var coder: Coder<ArraySlice<Byte>, [Byte]> { .init() }
}

extension RFC_768.Length: Coder.Codable {}
