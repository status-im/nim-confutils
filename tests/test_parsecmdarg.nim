# nim-confutils
# Copyright (c) 2022-2023 Status Research & Development GmbH
# Licensed and distributed under either of
#   * MIT license: [LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT
#   * Apache License, Version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
# at your option. This file may not be copied, modified, or distributed except according to those terms.

import
  std/[sequtils],
  unittest2,
  ../confutils

func testValidValues[T](lo: T = low(T), hi: T = high(T)): bool =
  allIt(lo .. hi, T.parseCmdArg($it) == it)

func testInvalidValues[T](lo, hi: int64): bool =
  static: doAssert low(int64) <= low(T).int64 and high(int64) >= high(T).int64
  allIt(
    lo .. hi,
    try:
      discard parseCmdArg(T, $it)
      false
    except ValueError:
      true
  )

func highPlusOne(T: type): string =
  result = $T.high
  assert result[^1] != '9'
  result[^1] = chr(result[^1].ord + 1)

func lowMinusOne(T: type): string =
  result = $T.low
  assert result[^1] != '9'
  result[^1] = chr(result[^1].ord + 1)

const span = 300000

suite "parseCmdArg":
  # For 8 and 16-bit integer types, there aren't many valid possibilities. Test
  # them all.
  test "int8":
    const
      lowBase = int16(low(int8)) - 1
      highBase = int16(high(int8)) + 1
    check:
      testInvalidValues[int8](lowBase * 2, lowBase)
      testValidValues[int8]()
      testInvalidValues[int8](highBase, highBase + span)

  test "int16":
    check: testValidValues[int16]()

  test "int32":
    check:
      testValidValues[int32](-span, span)
      # https://github.com/nim-lang/Nim/issues/16353 so target high(T) - 1
      testValidValues[int32](high(int32) - span, high(int32) - 1)

  test "int64":
    const
      highBase = int64(high(int32)) + 1
      lowBase = int64(low(int32)) - 1
    check:
      testValidValues[int64](low(int64), low(int64) + span)
      testValidValues[int64](lowBase - span, lowBase)
      testValidValues[int64](-span, span)
      testValidValues[int64](highBase, highBase + span)

      # https://github.com/nim-lang/Nim/issues/16353 so target high(T) - 1
      testValidValues[int64](high(int64) - span, high(int64) - 1)

    let i64HighPlusOne = highPlusOne(int64)
    expect(ValueError):
      discard parseCmdArg(int64, i64HighPlusOne)
    expect(ValueError):
      discard parseCmdArg(int64, $int64.high & "123")

    let i64LowMinusOne = lowMinusOne(int64)
    expect(ValueError):
      discard parseCmdArg(int64, i64LowMinusOne)
    expect(ValueError):
      discard parseCmdArg(int64, $int64.low & "123")

  test "uint8":
    const highBase = int16(high(uint8)) + 1
    check:
      testValidValues[uint8]()
      testInvalidValues[uint8](highBase, highBase + span)

  test "uint16":
    const highBase = int32(high(uint16)) + 1
    check:
      testValidValues[uint16]()
      testInvalidValues[uint16](highBase, highBase + span)

  test "uint32":
    const highBase = int64(high(uint32)) + 1
    check:
      testValidValues[uint32](0, 2000000)

      # https://github.com/nim-lang/Nim/issues/16353 so target high(T) - 1
      testValidValues[uint32](high(uint32) - span, high(uint32) - 1)
      testInvalidValues[uint32](highBase, highBase + span)

  test "uint64":
    const highBase = uint64(high(uint32)) + 1
    check:
      testValidValues[uint64](0, span)
      testValidValues[uint64](highBase, highBase + span)

      # https://github.com/nim-lang/Nim/issues/16353 so target high(T) - 1
      testValidValues[uint64](high(uint64) - span, high(uint64) - 1)

    let u64HighPlusOne = highPlusOne(uint64)
    expect(ValueError):
      discard parseCmdArg(uint64, u64HighPlusOne)
    expect(ValueError):
      discard parseCmdArg(uint64, $uint64.high & "123")

  test "bool":
    for trueish in ["y", "yes", "true", "1", "on"]:
      check: bool.parseCmdArg(trueish)
    for falsey in ["n", "no", "false", "0", "off"]:
      check: not bool.parseCmdArg(falsey)
    for invalid in ["2", "-1", "ncd"]:
      check:
        try:
          discard bool.parseCmdArg(invalid)
          false
        except ValueError:
          true

  test "enum":
    type TestEnumArg {.pure.} = enum
      arg1 = "Arg1"
      arg2
      Arg3
    check:
      parseCmdArg(TestEnumArg, "Arg1") == TestEnumArg.arg1
      parseCmdArg(TestEnumArg, "arg1") == TestEnumArg.arg1
      parseCmdArg(TestEnumArg, "aRG1") == TestEnumArg.arg1
      parseCmdArg(TestEnumArg, "arg2") == TestEnumArg.arg2
      parseCmdArg(TestEnumArg, "Arg2") == TestEnumArg.arg2
      parseCmdArg(TestEnumArg, "aRG2") == TestEnumArg.arg2
      parseCmdArg(TestEnumArg, "arg3") == TestEnumArg.Arg3
      parseCmdArg(TestEnumArg, "Arg3") == TestEnumArg.Arg3
      parseCmdArg(TestEnumArg, "aRG3") == TestEnumArg.Arg3
    expect ValueError:
      discard parseCmdArg(TestEnumArg, "Arg123")
