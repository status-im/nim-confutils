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
      "This multi " &
      "line " &
      "work"
    printCommand =
      "Multi lines with these " &
      "triple quoted strings work"

# TODO: https://github.com/nim-lang/Nim/pull/25401
#    printCommand = """Multi lines with these
#  triple quoted strings work"""

  ExporterConf* = object
    case cmd* {.
      command
      defaultValue: exportCommand .}: ExporterCmd
    of exportCommand:
      discard
    of printCommand:
      discard

let c = ExporterConf.load(termWidth = int.high)
