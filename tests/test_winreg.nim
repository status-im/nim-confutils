import
  unittest,
  ../confutils/winreg/winreg_serialization

type
  Fruit = enum
    Apple

const
  commonPath = "SOFTWARE\\nimbus"

template readWrite(key: string, val: typed) =
  test key:
    var ok = setValue(HKCU, commonPath, key, val)
    check ok == true
    var outVal: type val
    ok = getValue(HKCU, commonPath, key, outVal)
    check ok == true
    check outVal == val

proc testWinregUtils() =
  suite "winreg utils test suite":
    readWrite("some number", 123'u32)
    readWrite("some number 64", 123'u64)
    readWrite("some bytes", @[1.byte, 2.byte])
    readWrite("some int list", @[4,5,6])
    readWrite("some array", [1.byte, 2.byte, 4.byte])
    readWrite("some string", "hello world")
    readWrite("some enum", Apple)
    readWrite("some boolean", true)
    readWrite("some float32", 1.234'f32)
    readWrite("some float64", 1.234'f64)

    test "parse winregpath":
      let (hKey, path) = parseWinregPath("HKEY_CLASSES_ROOT\\" & commonPath)
      check hKey == HKCR
      check path == commonPath

testWinregUtils()
