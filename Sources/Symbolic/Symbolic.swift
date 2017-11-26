import Foundation

#if os(macOS)
import Darwin
#elseif os(Linux)
import Glibc
import GlibcDlfcnShim
#endif

enum LoadError: Error {
  case dlerror(String)
}

private func withDLError<T>(_ fn: () -> T) throws -> T {
  let val = fn()
  if let err = dlerror() {
    throw LoadError.dlerror(String(cString: err))
  }
  return val
}

public class SharedObject {
  public enum LoadBehavior {
    /// Perform lazy binding. Only resolve symbols as the code that references
    /// them is executed. If the symbol is never referenced, then it is never
    /// resolved. (Lazy binding is only performed for function references;
    /// references to variables are always immediately bound when the library
    /// is loaded.)
    case lazy

    /// If this value is specified, or the environment variable LD_BIND_NOW is
    /// set to a nonempty string, all undefined symbols in the library are
    /// resolved before dlopen() returns. If this cannot be done, an error is
    /// returned.
    case now
  }

  public struct LoadFlags: OptionSet {
    public let rawValue: Int32

    /// This is the converse of `.global`, and the default if neither flag is
    /// specified. Symbols defined in this library are not made available to
    /// resolve references in subsequently loaded libraries.
    public static let local = LoadFlags(rawValue: RTLD_LOCAL)

    /// The symbols defined by this library will be made available for symbol
    /// resolution of subsequently loaded libraries.
    public static let global = LoadFlags(rawValue: RTLD_GLOBAL)

    /// Don't load the library. This can be used to test if the library is
    /// already resident (dlopen() returns NULL if it is not, or the library's
    /// handle if it is resident). This flag can also be used to promote the
    /// flags on a library that is already loaded. For example, a library that
    /// was previously loaded with RTLD_LOCAL can be reopened with
    /// `[.noLoad, .global]`. This flag is not specified in POSIX.1-2001.
    public static let noLoad = LoadFlags(rawValue: RTLD_NOLOAD)

    /// Do not unload the library during dlclose(). Consequently, the library's
    /// static variables are not reinitialized if the library is reloaded with
    /// dlopen() at a later time. This flag is not specified in POSIX.1-2001.
    public static let noDelete = LoadFlags(rawValue: RTLD_NODELETE)

    /// Initalizes a set of flags with a given raw integer value.
    public init(rawValue: Int32) {
      self.rawValue = rawValue
    }
  }

  /// The file URL to the provided object.
  public let object: URL

  /// Whether this handle is owned and must be closed on `deinit`.
  private let ownsHandle: Bool

  /// The handle opened by `dlopen`.
  private let handle: UnsafeRawPointer

  public init(object: URL, behavior: LoadBehavior = .lazy,
              flags: LoadFlags = [.local]) throws {

    var rawFlags = flags.rawValue

    switch behavior {
    case .lazy:
      rawFlags |= RTLD_LAZY
    case .now:
      rawFlags |= RTLD_NOW
    }

    self.object = object
    self.handle = UnsafeRawPointer(try withDLError {
      dlopen(object.path, rawFlags)
    })
    self.ownsHandle = !flags.contains(.noLoad)
  }

  /// Creates a SharedObject for the provided DSO handle.
  private init(handle: UnsafeRawPointer) {
    let info = SymbolInfo(address: handle)!
    self.object = info.filename!
    self.handle = handle
    self.ownsHandle = false
  }

  /// The symbol info for this object.
  public var symbolInfo: SymbolInfo {
    return SymbolInfo(filename: object,
                      fileBaseAddress: UnsafeRawPointer(handle))
  }

  /// Returns the SharedObject for the current object file.
  /// - parameter dsohandle: This is defaulted to the `#dsohandle` of the
  ///                        caller, which is what enables this method to
  ///                        reliably get access to the shared object that the
  ///                        caller resides in. You should not pass any argument
  ///                        to this method, as that will not guarantee you will
  ///                        get the shared object you actually reside in.
  public static func current(
    _ dsohandle: UnsafeRawPointer = #dsohandle) -> SharedObject {
    return SharedObject(handle: dsohandle)
  }

  public func function<T>(forSymbol symbol: String, ofType type: T.Type) -> T? {
    guard let addr = address(ofSymbol: symbol) else { return nil }
    return unsafeBitCast(addr, to: type)
  }

  public func address(ofSymbol symbol: String) -> UnsafeRawPointer? {
    let mut = UnsafeMutableRawPointer(mutating: handle)
    guard let addr = dlsym(mut, symbol) else { return nil }
    return UnsafeRawPointer(addr)
  }

  public static func isLoaded(_ library: URL) -> Bool {
    return dlopen(library.path, RTLD_LAZY | RTLD_NOLOAD) != nil
  }

  deinit {
    if ownsHandle {
      dlclose(UnsafeMutableRawPointer(mutating: handle))
    }
  }
}

public struct SymbolInfo {
  /// The file name of the shared object this symbol resides in, if present.
  public let filename: URL?

  /// The base address at which the shared object is mapped into the address
  /// space of the calling process.
  public let fileBaseAddress: UnsafeRawPointer?

  /// The address of the symbol.
  public let symbolAddress: UnsafeRawPointer?

  /// The symbol name, if present.
  public let symbolName: String?

  /// Creates a new SymbolInfo with the provided file name and file base
  /// address.
  internal init(filename: URL, fileBaseAddress: UnsafeRawPointer) {
    self.filename = filename
    self.fileBaseAddress = fileBaseAddress
    self.symbolName = nil
    self.symbolAddress = nil
  }

  /// Gets the symbol information for the symbol with the provided address.
  /// - parameter address: The address of the symbol you intend to get.
  public init?(address: UnsafeRawPointer) {
    var info = Dl_info()
    guard dladdr(address, &info) != 0 else { return nil }
    self.init(info)
  }

  /// Creates a SymbolInfo from the corresponding dl_info.
  private init(_ dlinfo: Dl_info) {
    self.fileBaseAddress = UnsafeRawPointer(dlinfo.dli_fbase)
    self.symbolAddress = UnsafeRawPointer(dlinfo.dli_saddr)
    self.symbolName = (dlinfo.dli_sname as Optional).map(String.init(cString:))
    let filenameStr = (dlinfo.dli_fname as Optional).map(String.init(cString:))
    self.filename = filenameStr.map(URL.init(fileURLWithPath:))
  }
}
