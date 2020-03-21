extension CSVWriter {
    /// Configuration for how to write CSV data.
    public struct Configuration {
        /// The field and row delimiters.
        public var delimiters: Delimiter.Pair
        /// The row of headers to write at the beginning of the CSV data.
        ///
        /// If empty, no row will be written.
        public var headers: [String]
        /// The encoding used to serialize the CSV information.
        ///
        /// If no encoding is provided, UTF8 is presumed unless the CSV writer points to a file, in which case that file encoding will be used.
        public var encoding: String.Encoding?
        /// Indicates whether a [Byte Order Mark](https://en.wikipedia.org/wiki/Byte_order_mark) will be included at the beginning of the CSV representation.
        ///
        /// The BOM indicates the string encoding used for the CSV representation. If any, they always are the first bytes being writen.
        public var serializeBOM: BOMSerialization

        /// Designated initlaizer setting the default values.
        public init() {
            self.delimiters = (field: ",", row: "\n")
            self.headers = .init()
            self.encoding = nil
            self.serializeBOM = .standard
        }
    }
}

extension CSVWriter {
    /// Private configuration variables for the CSV writer.
    internal struct Settings {
        /// The unicode scalar delimiters for fields and rows.
        let delimiters: Delimiter.RawPair
        /// Boolean indicating whether the received CSV contains a header row or not.
        let headers: [String]
        /// The unicode scalar used as encapsulator and escaping character (when printed two times).
        let escapingScalar: Unicode.Scalar = "\""
        /// The bytes representing the BOM encoding. If empty, no bytes will be written.
        let bom: [UInt8]

        /// Designated initializer taking generic CSV configuration (with possible unknown data) and making it specific to a CSV writer instance.
        /// - parameter configuration: The public CSV writer configuration variables.
        /// - throws: `CSVWriter.Error` exclusively.
        init(configuration: CSVWriter.Configuration, fileEncoding: String.Encoding?) throws {
            // 1. Copy headers.
            self.headers = configuration.headers
            // 2. Validate the delimiters.
            let (field, row) = (configuration.delimiters.field.rawValue, configuration.delimiters.row.rawValue)
            if field.isEmpty || row.isEmpty {
                throw Error.invalidEmptyDelimiter()
            } else if field.elementsEqual(row) {
                throw Error.invalidDelimiters(field)
            } else {
                self.delimiters = (field, row)
            }
            // 3. Set up the right BOM.
            let encoding: String.Encoding
            switch (configuration.encoding, fileEncoding) {
            case (let e?, nil): encoding = e
            case (nil, let e?): encoding = e
            case (nil, nil): encoding = .utf8
            case (let lhs?, let rhs?) where lhs == rhs: encoding = lhs
            case (let lhs?, let rhs?): throw Error.invalidEncoding(provided: lhs, file: rhs)
            }
            
            switch (configuration.serializeBOM, encoding) {
            case (.always, .utf8): self.bom = BOM.UTF8
            case (.always, .utf16LittleEndian): self.bom = BOM.UTF16.littleEndian
            case (.always, .utf16BigEndian),
                 (.always, .utf16),   (.standard, .utf16),
                 (.always, .unicode), (.standard, .unicode): self.bom = BOM.UTF16.bigEndian
            case (.always, .utf32LittleEndian): self.bom = BOM.UTF32.littleEndian
            case (.always, .utf32BigEndian),
                 (.always, .utf32),   (.standard, .utf32): self.bom = BOM.UTF32.bigEndian
            default: self.bom = .init()
            }
        }
    }
}

fileprivate extension CSVWriter.Error {
    /// Error raised when the provided string encoding is different than the inferred file encoding.
    /// - parameter provided: The string encoding provided by the user.
    /// - parameter file: The string encoding in the targeted file.
    static func invalidEncoding(provided: String.Encoding, file: String.Encoding) -> CSVError<CSVWriter> {
        .init(.invalidConfiguration,
              reason: "The encoding provided was different than the encoding detected on the file.",
              help: "Set the configuration encoding to nil or to the file encoding.",
              userInfo: ["Provided encoding": provided, "File encoding": file])
    }
    /// Error raised when the the field or/and row delimiters are empty.
    /// - parameter delimiter: The indicated field and row delimiters.
    static func invalidEmptyDelimiter() -> CSVError<CSVWriter> {
        .init(.invalidConfiguration,
              reason: "The delimiters cannot be empty.",
              help: "Set delimiters that at least contain a unicode scalar/character.")
    }
    
    /// Error raised when the field and row delimiters are the same.
    /// - parameter delimiter: The indicated field and row delimiters.
    static func invalidDelimiters(_ delimiter: String.UnicodeScalarView) -> CSVError<CSVWriter> {
        .init(.invalidConfiguration,
              reason: "The field and row delimiters cannot be the same.",
              help: "Set different delimiters for field and rows.",
              userInfo: ["Delimiter": delimiter])
    }
}