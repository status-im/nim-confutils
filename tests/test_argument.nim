# confutils
# Copyright (c) 2018-2025 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import unittest2, ../confutils, ./help/test_argument

suite "test argument":
  test "no command":
    let conf = TestConf.load(cmdLine = @[])
    check:
      conf.cmd == Lvl1Cmd.noCommand

  test "pass arg first to argAfterOpt":
    let conf = TestConf.load(cmdLine = @[
      "argAfterOpt",
      "foo",
      "--arg-after-opt-opt1=bar"
    ])
    check:
      conf.cmd == Lvl1Cmd.argAfterOpt
      conf.arg1 == "foo"
      conf.opt1 == "bar"

  test "pass arg last to argAfterOpt":
    let conf = TestConf.load(cmdLine = @[
      "argAfterOpt",
      "--arg-after-opt-opt1=bar",
      "foo"
    ])
    check:
      conf.cmd == Lvl1Cmd.argAfterOpt
      conf.arg1 == "foo"
      conf.opt1 == "bar"

  test "pass arg first to argBeforeOpt":
    let conf = TestConf.load(cmdLine = @[
      "argBeforeOpt",
      "foo",
      "--arg-before-opt-opt2=bar"
    ])
    check:
      conf.cmd == Lvl1Cmd.argBeforeOpt
      conf.arg2 == "foo"
      conf.opt2 == "bar"

  test "pass arg last to argBeforeOpt":
    let conf = TestConf.load(cmdLine = @[
      "argBeforeOpt",
      "--arg-before-opt-opt2=bar",
      "foo"
    ])
    check:
      conf.cmd == Lvl1Cmd.argBeforeOpt
      conf.arg2 == "foo"
      conf.opt2 == "bar"

  test "pass arg first to argAroundOpt":
    let conf = TestConf.load(cmdLine = @[
      "argAroundOpt",
      "foo",
      "bar",
      "--arg-around-opt-opt3=baz"
    ])
    check:
      conf.cmd == Lvl1Cmd.argAroundOpt
      conf.arg4 == "foo"
      conf.arg5 == "bar"
      conf.opt3 == "baz"

  test "pass arg last to argAroundOpt":
    let conf = TestConf.load(cmdLine = @[
      "argAroundOpt",
      "--arg-around-opt-opt3=baz",
      "foo",
      "bar"
    ])
    check:
      conf.cmd == Lvl1Cmd.argAroundOpt
      conf.arg4 == "foo"
      conf.arg5 == "bar"
      conf.opt3 == "baz"

  test "pass arg mix to argAroundOpt":
    let conf = TestConf.load(cmdLine = @[
      "argAroundOpt",
      "foo",
      "--arg-around-opt-opt3=baz",
      "bar"
    ])
    check:
      conf.cmd == Lvl1Cmd.argAroundOpt
      conf.arg4 == "foo"
      conf.arg5 == "bar"
      conf.opt3 == "baz"
