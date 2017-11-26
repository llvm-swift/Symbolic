# Symbolic

Symbolic makes it easy to get information about an executable, shared object,
or static library.

## Usage

### Note

⚠️ This library is incredibly unsafe. Use it with caution! ⚠️

To dynamically load a shared object file, create a `SharedObject`, passing in
the file URL where the object resides.

You can also use `SharedObject.current()` to get ahold of the object in which
your code will reside once compiled.

```swift
let libFoo = SharedObject(object: URL(fileURLWithPath: "/usr/lib/libfoo.dylib"))
let myExe = SharedObject.current()
```

From there, you can ask the object for the addresses of symbols in the object
and (if you're adventurous) cast function addresses to `@convention(c)`
function pointers.

```swift
let libcURL = URL(fileURLWithPath: "/usr/lib/libc.dylib")
let libc = SharedObject(object: libcURL)

let addr = libc.address(forSymbol: "sin") // will not be `nil`

typealias SinFn = @convention(c) (Double) -> Double

// Will perform an unsafeBitCast on your behalf!
let sinFn = libc.function(forSymbol: "sin", ofType: SinFn.self)

sinFn?(0.5) // 0.4794255386
```

Additionally, if you have an address in mind that you've already linked, you
can ask for it directly in your current address space:

```swift
let addrInfo = SymbolInfo(address: addr)
addrInfo.symbolName // "sin"
```

## Author

Harlan Haskins ([@harlanhaskins](https://github.com/harlanhaskins))

## License

This project is released under the MIT license, a copy of which is avaialable
in this repository.
