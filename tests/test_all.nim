# nim-confutils
# Copyright (c) 2020-2022 Status Research & Development GmbH
# Licensed and distributed under either of
#   * MIT license: [LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT
#   * Apache License, Version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
# at your option. This file may not be copied, modified, or distributed except according to those terms.

{. warning[UnusedImport]:off .}

import
  test_argument,
  test_case_opt,
  test_config_file,
  test_dispatch,
  test_duplicates,
  test_envvar,
  test_ignore,
  test_multi_case_values,
  test_nested_cmd,
  test_parsecmdarg,
  test_pragma,
  test_qualified_ident,
  test_results_opt,
  test_help

when defined(windows):
  import test_winreg
