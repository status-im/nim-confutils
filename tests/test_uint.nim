# confutils
# Copyright (c) 2018-2025 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import unittest2, ../confutils

# see test_parsecmdarg.nim for parseCmdArg uint tests
# and tests/fail/test_uint*_no_wrap.nim

type
  Command* = enum
    noCommand

  IntConf* = object
    case cmd {.
      command
      defaultValue: noCommand }: Command

    of noCommand:
      uint8Arg*: uint8
      uint16Arg*: uint16
      uint32Arg*: uint32

suite "test uint":
  test "no command uint high":
    let conf = IntConf.load(cmdLine = @[
      "--uint8Arg=" & $uint8.high,
      "--uint16Arg=" & $uint16.high,
      "--uint32Arg=" & $uint32.high
    ])
    check:
      conf.cmd == Command.noCommand
      conf.uint8Arg == uint8.high
      conf.uint16Arg == uint16.high
      conf.uint32Arg == uint32.high
