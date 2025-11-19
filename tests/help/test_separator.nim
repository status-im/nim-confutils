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
      separator: "Network Options:"
      defaultValue: "opt1 default"
      desc: "opt1 desc"
      name: "opt1" }: string
    opt2 {.
      defaultValue: "opt2 default"
      desc: "opt2 desc"
      name: "opt2" }: string
    opt3 {.
      separator: "\p----------------"
      defaultValue: "opt3 default"
      desc: "opt3 desc"
      name: "opt3" }: string

let c = TestConf.load(termWidth = int.high)
