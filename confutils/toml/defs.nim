# confutils
# Copyright (c) 2018-2024 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

{.push raises: [], gcsafe.}

# Optional toml support - add `requires "toml_serialization"` to your package
# dependencies before using

import
  toml_serialization,
  toml_serialization/pkg/results as tomlResults, ../defs as confutilsDefs

export toml_serialization, tomlResults, confutilsDefs

type ConfTypes = InputFile | InputDir | OutPath | OutDir | OutFile
serializesAsBase(ConfTypes, Toml)

{.pop.}
