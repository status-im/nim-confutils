# confutils
# Copyright (c) 2018-2024 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import std/net
from std/parseutils import parseInt
export net

{.push gcsafe, raises: [].}

func parseCmdArg*(T: type IpAddress, s: string): T {.gcsafe, raises: [ValueError].} =
  parseIpAddress(s)

func completeCmdArg*(T: type IpAddress, val: string): seq[string] =
  # TODO: Maybe complete the local IP address?
  @[]

func parseCmdArg*(T: type Port, s: string): T {.gcsafe, raises: [ValueError].} =
  template fail =
    raise newException(ValueError,
      "The supplied port must be an integer value in the range 1-65535")

  var intVal: int
  let parsedChars = try: parseInt(s, intVal)
                    except CatchableError: fail()

  if parsedChars != len(s) or intVal < 1 or intVal > 65535:
    fail()

  return Port(intVal)

func completeCmdArg*(T: type Port, val: string): seq[string] =
  @[]

{.pop.}
