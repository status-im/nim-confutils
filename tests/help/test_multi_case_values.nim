# confutils
# Copyright (c) 2018-2026 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import ../../confutils

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

let c = TestConf.load(termWidth = int.high)
