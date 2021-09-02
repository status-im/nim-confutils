import os
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

  exec "nim c --threads:off -d:release tests/test_duplicates"
  exec "nim c --threads:on -d:release tests/test_duplicates"

  #Also iterate over every test in tests/fail, and verify they fail to compile.
  echo "\r\nTest Fail to Compile:"
  for path in listFiles(thisDir() / "tests" / "fail"):
    if path.split(".")[^1] != "nim":
      continue

    if gorgeEx("nim c " & path).exitCode != 0:
      echo "  [OK] ", path.split(DirSep)[^1]
    else:
      echo "  [FAILED] ", path.split(DirSep)[^1]
      exec "exit 1"
