# confutils
# Copyright (c) 2018-2025 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import ../../confutils

type
  Lvl1Cmd = enum
    lvl1Cmd1

  TestConf = object
    opt1 {.
      desc: "opt1 regular description"
      defaultValue: "opt1 default"
      name: "opt1" }: string
    hidden1 {.
      hidden
      desc: "hidden1 regular description"
      defaultValue: "hidden1 default"
      name: "hidden1-with-a-long-name" }: string
    debug1 {.
      debug
      desc: "debug1 regular description"
      defaultValue: "debug1 default"
      name: "debug1" }: string

    case cmd {.command.}: Lvl1Cmd
    of Lvl1Cmd.lvl1Cmd1:
      opt2 {.
        desc: "opt2 regular description"
        defaultValue: "opt2 default"
        name: "opt2" }: string
      hidden2 {.
        hidden
        desc: "hidden2 regular description"
        defaultValue: "hidden2 default"
        name: "hidden2-with-a-long-name" }: string
      debug2 {.
        debug
        defaultValue: "debug2 default"
        desc: "debug2 desc"
        name: "debug2" }: string

let c = TestConf.load(termWidth = int.high)
