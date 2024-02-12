# confutils
# Copyright (c) 2018-2024 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  std/uri,
  toml_serialization, toml_serialization/lexer

export
  uri, toml_serialization

proc readValue*(r: var TomlReader, val: var Uri)
               {.raises: [SerializationError, IOError, Defect].} =
  val =  try: parseUri(r.readValue(string))
         except ValueError as err:
           r.lex.raiseUnexpectedValue("URI")

