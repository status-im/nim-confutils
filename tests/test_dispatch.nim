# confutils
# Copyright (c) 2018-2026 Status Research & Development GmbH
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

  test "grouped params":
    var a: int
    var b: int
    proc simple(foo, bar: int) =
      a = foo
      b = bar
    dispatch(simple, cmdLine = @[
      "--foo=123",
      "--bar=456"
    ])
    check:
      a == 123
      b == 456

  test "cli grouped params":
    var a: int
    var b: int
    cli(cmdLine = @[
      "--foo=123",
      "--bar=456"
    ]) do (foo, bar: int):
      a = foo
      b = bar
    check:
      a == 123
      b == 456

  test "cli return value":
    let a = cli(cmdLine = @[
      "--foo=123"
    ]) do (foo: int) -> int:
      foo + 1
    check a == 124

  test "proc declared in template":
    var a: int
    var b: string
    template declareAndDispatch() =
      proc simple(foo: int, bar = "abc") =
        a = foo
        b = bar
      dispatch(simple, cmdLine = @[
        "--foo=123",
        "--bar=def"
      ])
    declareAndDispatch()
    check:
      a == 123
      b == "def"

  test "cli in template":
    template cliInTemplate(): int =
      cli(cmdLine = @[
        "--foo=123"
      ]) do (foo: int) -> int:
        foo + 1
    check cliInTemplate() == 124

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

  test "cli param pragmas":
    let a = cli(cmdLine = @[
      "--foo=1",
      "--qux=2",
      "x"
    ]) do (
        foo, bar {.defaultValue: 5.}: int, qux {.desc: "q".}: int,
        args {.argument.}: seq[string]) -> string:
      $foo & ":" & $bar & ":" & $qux & ":" & $args
    check a == "1:5:2:@[\"x\"]"
