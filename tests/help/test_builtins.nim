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
    foobar1 {.
      defaultValue: 1
      desc: "foobar1 desc"
      name: "foobar1" }: int

    case cmd {.
      command
      defaultValue: Lvl1Cmd.lvl1Cmd1 }: Lvl1Cmd
    of Lvl1Cmd.lvl1Cmd1:
      foobar2 {.
        defaultValue: 2
        desc: "foobar2 desc"
        name: "foobar2" }: int


let c = TestConf.load(version = "1.2.3", termWidth = int.high)
