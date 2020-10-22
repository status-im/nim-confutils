mode = ScriptMode.Verbose

packageName   = "confutils"
version       = "0.1.0"
author        = "Status Research & Development GmbH"
description   = "Simplified handling of command line options and config files"
license       = "Apache License 2.0"
skipDirs      = @["tests"]

requires "nim >= 1.0.0",
         "stew"

task test, "Run all tests":
  exec "nim c -r --threads:off -d:release tests/test_all"
  exec "nim c -r --threads:on -d:release tests/test_all"
