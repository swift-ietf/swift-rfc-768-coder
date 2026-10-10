public import Byte
public import Coder
public import Cursor
public import RFC_768
import Binary
import Parser
import Serializer

extension RFC_768.Datagram {

    public struct Coder<Input: Cursor.`Protocol`<Byte, Never>, Buffer: RangeReplaceableCollection<Byte>>: Coding {


        public typealias Output = RFC_768.Datagram

        public typealias Failure = RFC_768.Datagram.Error

        public init() {}

        public borrowing func parse(_ input: inout Input) throws(Failure) -> Output {
            let start = input.checkpoint

            let header: RFC_768.Header
            do throws(RFC_768.Header.Error) {
                header = try RFC_768.Header.Coder<Input, Buffer>().parse(&input)
            } catch {
                input.seek(to: start)
                throw .header(error)
            }

            let expected = Int(header.length.data)
            var data: [Byte] = []
            data.reserveCapacity(expected)

            while data.count < expected {
                guard let byte = input.next() else {
                    input.seek(to: start)
                    throw .insufficientData(expected: expected, got: data.count)
                }
                data.append(byte)
            }

            return RFC_768.Datagram(header: header, data: data)
        }

        public borrowing func serialize(_ output: Output, into buffer: inout Buffer) throws(Failure) {
            RFC_768.Datagram.serialize(output, into: &buffer)
        }
    }

    public static var coder: Coder<ArraySlice<Byte>, [Byte]> { .init() }
}
