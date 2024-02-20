# confutils
# Copyright (c) 2018-2024 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  std/net,
  toml_serialization, toml_serialization/lexer

export
  net, toml_serialization

{.push gcsafe, raises: [].}

proc readValue*(r: var TomlReader, val: var IpAddress)
               {.raises: [SerializationError, IOError].} =
  val =  try: parseIpAddress(r.readValue(string))
         except ValueError as err:
           r.lex.raiseUnexpectedValue("IP address " & err.msg)

proc readValue*(r: var TomlReader, val: var Port)
               {.raises: [SerializationError, IOError].} =
  let port = try: r.readValue(uint16)
             except ValueError as exc:
               r.lex.raiseUnexpectedValue("Port " & exc.msg)

  val = Port port

{.pop.}
