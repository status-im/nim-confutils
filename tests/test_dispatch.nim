# confutils
# Copyright (c) 2018-2025 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import unittest2, ../confutils

suite "test dispatch":
  test "required params":
    var a: int
    var b: string
    proc simple(foo: int, bar: string) =
      a = foo
      b = bar
    dispatch(simple, cmdLine = @[
      "--foo=123",
      "--bar=baz",
    ])
    check:
      a == 123
      b == "baz"

  test "default param":
    var a: int
    var b: string
    proc simple(foo: int, bar: string = "abc") =
      a = foo
      b = bar
    dispatch(simple, cmdLine = @[
      "--foo=123"
    ])
    check:
      a == 123
      b == "abc"

  test "set default param":
    var a: int
    var b: string
    proc simple(foo: int, bar: string = "abc") =
      a = foo
      b = bar
    dispatch(simple, cmdLine = @[
      "--foo=123",
      "--bar=def"
    ])
    check:
      a == 123
      b == "def"

  test "default param implicit type":
    var a: int
    var b: string
    proc simple(foo: int, bar = "abc") =
      a = foo
      b = bar
    dispatch(simple, cmdLine = @[
      "--foo=123"
    ])
    check:
      a == 123
      b == "abc"

  test "set default param implicit type":
    var a: int
    var b: string
    proc simple(foo: int, bar = "abc") =
      a = foo
      b = bar
    dispatch(simple, cmdLine = @[
      "--foo=123",
      "--bar=def"
    ])
    check:
      a == 123
      b == "def"

  # proc param pragmas are ignored in older versions
  when (NimMajor, NimMinor) >= (2, 2):
    test "default pragma":
      var a: int
      var b: string
      proc simple(foo: int, bar {.defaultValue: "abc".}: string) =
        a = foo
        b = bar
      dispatch(simple, cmdLine = @[
        "--foo=123"
      ])
      check:
        a == 123
        b == "abc"

    test "set default pragma":
      var a: int
      var b: string
      proc simple(foo: int, bar {.defaultValue: "abc".}: string) =
        a = foo
        b = bar
      dispatch(simple, cmdLine = @[
        "--foo=123",
        "--bar=def"
      ])
      check:
        a == 123
        b == "def"

    test "cli example":
      var
        a: int
        b: string
        c: bool
        d: seq[string]
      proc simple(
          foo: int, bar: string, withBaz: bool, args {.argument.}: seq[string]
      ) =
        a = foo
        b = bar
        c = withBaz
        d = args
      dispatch(simple, cmdLine = @[
        "--foo=123",
        "--bar=abc",
        "--withBaz=true",
        "def",
        "hij"
      ])
      check:
        a == 123
        b == "abc"
        c == true
        d == @["def", "hij"]
