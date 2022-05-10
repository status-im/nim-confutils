# nim-confutils
# Copyright (c) 2020-2022 Status Research & Development GmbH
# Licensed and distributed under either of
#   * MIT license: [LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT
#   * Apache License, Version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
# at your option. This file may not be copied, modified, or distributed except according to those terms.

{. warning[UnusedImport]:off .}

import
  test_ignore,
  test_config_file,
  test_envvar,
  test_parsecmdarg,
  test_pragma,
  test_qualified_ident

when defined(windows):
  import test_winreg
