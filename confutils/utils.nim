# confutils
# Copyright (c) 2018-2025 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import std/macros

proc dotExpr*(a, b: NimNode): NimNode =
  ## Return merged dot expr of `a.b`;
  ## `a` or `b` can be dot expr
  if b.kind == nnkDotExpr:
    dotExpr(dotExpr(a, b[0]), b[1])
  else:
    newDotExpr(a, b)
