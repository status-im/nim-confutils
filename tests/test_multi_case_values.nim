# confutils
# Copyright (c) 2018-2026 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import unittest2, ../confutils

type
  Cmd = enum
    cmd1
    cmd2

  TestConf = object
    case cmd {.command.}: Cmd
    of Cmd.cmd1, Cmd.cmd2:
      opt1 {.
        defaultValue: "opt1 default"
        desc: "opt1 desc"
        name: "opt1" }: string

  RangeCmd = enum
    rangeCmd1
    rangeCmd2
    rangeCmd3

  TestRangeConf = object
    case cmd {.command.}: RangeCmd
    of rangeCmd1:
      opt1 {.
        defaultValue: "opt1 default"
        desc: "opt1 desc"
        name: "opt1" }: string
    of RangeCmd.rangeCmd2 .. RangeCmd.rangeCmd3:
      opt2 {.
        defaultValue: "opt2 default"
        desc: "opt2 desc"
        name: "opt2" }: string

  SetCmd = enum
    setCmd1
    setCmd2
    setCmd3

const setCmds = {SetCmd.setCmd2, SetCmd.setCmd3}

type
  TestSetConf = object
    case cmd {.command.}: SetCmd
    of setCmd1:
      opt1 {.
        defaultValue: "opt1 default"
        desc: "opt1 desc"
        name: "opt1" }: string
    of setCmds:
      opt2 {.
        defaultValue: "opt2 default"
        desc: "opt2 desc"
        name: "opt2" }: string

suite "test multi case subcommand values":
  test "options work for the first subcommand":
    let conf = TestConf.load(cmdLine = @[
       "cmd1"
    ])
    check:
      conf.cmd == Cmd.cmd1
      conf.opt1 == "opt1 default"

  test "options work for the second subcommand":
    let conf = TestConf.load(cmdLine = @[
       "cmd2"
    ])
    check:
      conf.cmd == Cmd.cmd2
      conf.opt1 == "opt1 default"

  test "set option for first subcommand":
    let conf = TestConf.load(cmdLine = @[
       "cmd1", "--opt1=foobar"
    ])
    check:
      conf.cmd == Cmd.cmd1
      conf.opt1 == "foobar"

  test "set option for second subcommand":
    let conf = TestConf.load(cmdLine = @[
       "cmd2", "--opt1=foobar"
    ])
    check:
      conf.cmd == Cmd.cmd2
      conf.opt1 == "foobar"

suite "test range case subcommand values":
  test "set option for first subcommand in range":
    let conf = TestRangeConf.load(cmdLine = @[
       "rangeCmd2", "--opt2=foobar"
    ])
    check:
      conf.cmd == RangeCmd.rangeCmd2
      conf.opt2 == "foobar"

  test "set option for last subcommand in range":
    let conf = TestRangeConf.load(cmdLine = @[
       "rangeCmd3", "--opt2=foobar"
    ])
    check:
      conf.cmd == RangeCmd.rangeCmd3
      conf.opt2 == "foobar"

suite "test set case subcommand values":
  test "set option for first subcommand in set":
    let conf = TestSetConf.load(cmdLine = @[
       "setCmd2", "--opt2=foobar"
    ])
    check:
      conf.cmd == SetCmd.setCmd2
      conf.opt2 == "foobar"

  test "set option for last subcommand in set":
    let conf = TestSetConf.load(cmdLine = @[
       "setCmd3", "--opt2=foobar"
    ])
    check:
      conf.cmd == SetCmd.setCmd3
      conf.opt2 == "foobar"
