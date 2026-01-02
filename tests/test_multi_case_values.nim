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
