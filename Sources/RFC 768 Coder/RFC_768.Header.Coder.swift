public import Byte
public import Coder
public import Cursor
public import RFC_768
import Binary
import Parser
import Serializer

extension RFC_768.Header {

    public struct Coder<Input: Cursor.`Protocol`<Byte, Never>, Buffer: RangeReplaceableCollection<Byte>>: Coding {


        public typealias Output = RFC_768.Header

        public typealias Failure = RFC_768.Header.Error

        public init() {}

        public borrowing func parse(_ input: inout Input) throws(Failure) -> Output {
            let start = input.checkpoint

            let source: RFC_768.Port
            do throws(RFC_768.Port.Error) {
                source = try RFC_768.Port.Coder<Input, Buffer>().parse(&input)
            } catch {
                input.seek(to: start)
                throw .source(error)
            }

            let destination: RFC_768.Port
            do throws(RFC_768.Port.Error) {
                destination = try RFC_768.Port.Coder<Input, Buffer>().parse(&input)
            } catch {
                input.seek(to: start)
                throw .destination(error)
            }

            let length: RFC_768.Length
            do throws(RFC_768.Length.Error) {
                length = try RFC_768.Length.Coder<Input, Buffer>().parse(&input)
            } catch {
                input.seek(to: start)
                throw .length(error)
            }

            let checksum: RFC_768.Checksum
            do throws(RFC_768.Checksum.Error) {
                checksum = try RFC_768.Checksum.Coder<Input, Buffer>().parse(&input)
            } catch {
                input.seek(to: start)
                throw .checksum(error)
            }

            return RFC_768.Header(
                source: source,
                destination: destination,
                length: length,
                checksum: checksum
            )
        }

        public borrowing func serialize(_ output: Output, into buffer: inout Buffer) throws(Failure) {
            RFC_768.Header.serialize(output, into: &buffer)
        }
    }

    public static var coder: Coder<ArraySlice<Byte>, [Byte]> { .init() }
}
