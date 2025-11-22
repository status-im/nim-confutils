# confutils
# Copyright (c) 2018-2025 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import unittest2, ../confutils

type CustomString = distinct string

proc `==`(a, b: CustomString): bool =
  a.string == b.string

proc parseCmdArg(T: type CustomString, s: string): T {.raises: [ValueError].} =
  T(s & "_cs_overridden")

func completeCmdArg(T: type CustomString, val: string): seq[string] =
  @[]

type
  Lvl1Cmd = enum
    lvl1Cmd1

  Lvl2Cmd = enum
    lvl2Cmd1

  TestConf = object
    opt1 {.
      desc: "opt1 desc"
      name: "opt1" }: Opt[string]
    opt2 {.
      desc: "opt2 desc"
      name: "opt2" }: Opt[CustomString]

    case cmd {.command.}: Lvl1Cmd
    of Lvl1Cmd.lvl1Cmd1:
      lvl1Opt1 {.
        desc: "lvl1Opt1 desc"
        name: "lvl1-opt1" }: Opt[int]

      case cmd2 {.command.}: Lvl2Cmd
      of Lvl2Cmd.lvl2Cmd1:
        lvl2Opt1 {.
          desc: "lvl2Opt1 desc"
          name: "lvl2-opt1" }: Opt[int]

suite "test results Opt":
  test "defaults":
    let conf = TestConf.load(cmdLine = @[
      "lvl1Cmd1",
      "lvl2Cmd1"
    ])
    check:
      conf.cmd == Lvl1Cmd.lvl1Cmd1
      conf.cmd2 == Lvl2Cmd.lvl2Cmd1
      not conf.opt1.isOk
      not conf.opt2.isOk
      not conf.lvl1Opt1.isOk
      not conf.lvl2Opt1.isOk

  test "all opts":
    let conf = TestConf.load(cmdLine = @[
      "--opt1=foo",
      "--opt2=bar",
      "lvl1Cmd1",
      "--lvl1-opt1=123",
      "lvl2Cmd1",
      "--lvl2-opt1=456"
    ])
    check:
      conf.cmd == Lvl1Cmd.lvl1Cmd1
      conf.cmd2 == Lvl2Cmd.lvl2Cmd1
      conf.opt1.get == "foo"
      conf.opt2.get == "bar_cs_overridden".CustomString
      conf.lvl1Opt1.get == 123
      conf.lvl2Opt1.get == 456
