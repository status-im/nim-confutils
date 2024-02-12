# confutils
# Copyright (c) 2018-2024 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  strutils,
  stew/byteutils, testutils/fuzzing,
  ../confutils

template fuzzCliParsing*(Conf: type) =
  test:
    block:
      try:
        let cfg = Conf.load(cmdLine = split(fromBytes(string, payload)),
                            printUsage = false,
                            quitOnFailure = false)
      except ConfigurationError as err:
        discard

