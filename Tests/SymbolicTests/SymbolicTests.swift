import XCTest
@testable import Symbolic

#if os(macOS)
let testSharedLibraryExtension = "dylib"
#elseif os(Linux)
let testSharedLibraryExtension = "so"
#endif

func testLibrary(_ name: String) -> URL {
  let currentURL = URL(fileURLWithPath: #file)
  return currentURL
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("Resources")
    .appendingPathComponent("lib\(name).\(testSharedLibraryExtension)")
}

@_cdecl("symbolic_test_hook")
public func symbolicTestHook() -> Int32 {
  return 1
}

class SymbolicTests: XCTestCase {
  func testCurrentLibrary() {
    let currentObj = SharedObject.current()
    XCTAssert(currentObj.object.path.contains("Symbolic"))
    XCTAssertNotNil(currentObj.symbolInfo.filename)
    if let file = currentObj.symbolInfo.filename {
      XCTAssertEqual(currentObj.object, file)
    }
    XCTAssertNil(currentObj.symbolInfo.symbolName)
    XCTAssertNil(currentObj.symbolInfo.symbolAddress)

    typealias TestHookFn = @convention(c) () -> Int32

    let testHook1Fn = currentObj.function(forSymbol: "symbolic_test_hook",
                                          ofType: TestHookFn.self)
    XCTAssertNotNil(testHook1Fn)
    XCTAssertEqual(testHook1Fn?(), 1)
  }

  func testLoadLibrary() {
      do {
        let obj = try SharedObject(object: testLibrary("foo"))
        XCTAssertNotNil(obj.address(ofSymbol: "test_ret_1"))
        XCTAssertNotNil(obj.address(ofSymbol: "test_ret_hello"))

        typealias Ret1Fn = @convention(c) () -> Int32
        let ret1 = obj.function(forSymbol: "test_ret_1", ofType: Ret1Fn.self)
        XCTAssertNotNil(ret1)
        XCTAssertEqual(ret1?(), 1)

        typealias RetHelloFn = @convention(c) () -> UnsafeMutablePointer<Int8>
        let retHello = obj.function(forSymbol: "test_ret_hello",
                                    ofType: RetHelloFn.self)
        XCTAssertNotNil(retHello)
        if let result = retHello?() {
          XCTAssertEqual(String(cString: result), "hello")
        }
      } catch {
        XCTFail("could not load object: \(error)")
      }
  }

  static var allTests = [
    ("testCurrentLibrary", testCurrentLibrary),
    ("testLoadLibrary", testLoadLibrary),
  ]
}
