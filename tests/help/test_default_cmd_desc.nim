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
  ExporterCmd* = enum
    exportCommand =
      "Some very important description, must read this!"
    printCommand =
      "Some description"

  ExporterConf* = object
    case cmd* {.
      command
      defaultValue: exportCommand .}: ExporterCmd
    of exportCommand:
      port* {.
        defaultValue: 1
        desc: "some port"
        name: "port" .}: uint16
    of printCommand:
      portP* {.
        defaultValue: 1
        desc: "some port"
        name: "port" .}: uint16

let c = ExporterConf.load(termWidth = int.high)
