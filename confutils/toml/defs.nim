# confutils
# Copyright (c) 2018-2024 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  toml_serialization, ../defs as confutilsDefs

export
  toml_serialization, confutilsDefs

template readConfutilsType(T: type) =
  template readValue*(r: var TomlReader, val: var T) =
    val = T r.readValue(string)

readConfutilsType InputFile
readConfutilsType InputDir
readConfutilsType OutPath
readConfutilsType OutDir
readConfutilsType OutFile
