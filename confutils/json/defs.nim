# confutils
# Copyright (c) 2018-2024 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

{.push raises: [], gcsafe.}

# Optional json support - add `requires "json_serialization"` to your package
# dependencies before using

import serialization, json_serialization, ../defs as confutilsDefs

export json_serialization, confutilsDefs

type ConfTypes = InputFile | InputDir | OutPath | OutDir | OutFile
serializesAsBase(ConfTypes, Json)

{.pop.}
