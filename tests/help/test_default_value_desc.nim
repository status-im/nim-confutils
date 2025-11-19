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
  TestConf = object
    opt1 {.
      defaultValue: defaultEth2TcpPort
      defaultValueDesc: $defaultEth2TcpPort
      desc: "tcp port"
      name: "opt1" }: int

let c = TestConf.load(termWidth = int.high)
