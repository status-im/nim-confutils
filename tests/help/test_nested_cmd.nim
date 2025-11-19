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
    lvl1NoCommand
    lvl1Cmd1

  Lvl2Cmd = enum
    lvl2Cmd1
    lvl2Cmd2

  TestConf = object
    topArg1 {.
      defaultValue: "topArg1 default"
      desc: "topArg1 desc"
      name: "top-arg1" }: string

    case cmd {.
      command
      defaultValue: Lvl1Cmd.lvl1NoCommand }: Lvl1Cmd
    of Lvl1Cmd.lvl1NoCommand:
      lvl1NoCommandArg1 {.
        defaultValue: "lvl1NoCommandArg1 default"
        desc: "lvl1NoCommandArg1 desc"
        name: "lvl1-no-command-arg1" }: string
    of Lvl1Cmd.lvl1Cmd1:
      lvl1Cmd1Arg1 {.
        defaultValue: "lvl1Cmd1Arg1 default"
        desc: "lvl1Cmd1Arg1 desc"
        name: "lvl1-cmd1-arg1" }: string

      case lvl2Cmd {.command.}: Lvl2Cmd
      of Lvl2Cmd.lvl2Cmd1:
        lvl2Cmd1Arg1 {.
          defaultValue: "lvl2Cmd1Arg1 default"
          desc: "lvl2Cmd1Arg1 desc"
          name: "lvl2-cmd1-arg1" }: string
      of Lvl2Cmd.lvl2Cmd2:
        lvl2Cmd2Arg1 {.
          defaultValue: "lvl2Cmd2Arg1 default"
          desc: "lvl2Cmd2Arg1 desc"
          name: "lvl2-cmd2-arg1" }: string

let c = TestConf.load(termWidth = int.high)
