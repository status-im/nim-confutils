# confutils
# Copyright (c) 2018-2025 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import ../../confutils

const defaultEth2TcpPort = 9000

type
  TestOptsConf = object
    opt1 {.
      defaultValue: 123
      defaultValueDesc: "123"
      desc: "tcp port"
      name: "opt1" }: int

    opt2 {.
      defaultValue: 123
      desc: "udp port"
      name: "opt2" }: int

  TestConf = object
    opts {.flatten: (opt1: defaultEth2TcpPort, opt2: 8000).}: TestOptsConf

let c = TestConf.load(termWidth = int.high)
