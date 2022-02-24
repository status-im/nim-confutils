import os, strutils
mode = ScriptMode.Verbose

packageName   = "confutils"
version       = "0.1.0"
author        = "Status Research & Development GmbH"
description   = "Simplified handling of command line options and config files"
license       = "Apache License 2.0"
skipDirs      = @["tests"]

requires "nim >= 1.0.0",
         "stew"

proc run(args, path: string) =
  exec "nim " & getEnv("TEST_LANG", "c") & " " & getEnv("NIMFLAGS") & " " & args &
    " --hints:off --warnings:on --skipParentCfg --skipUserCfg" &
    " --styleCheck:usages --styleCheck:error " & path

task test, "Run all tests":
  run("--threads:off -d:release -r", "tests/test_all")
  run("--threads:on -d:release -r", "tests/test_all")

  run("--threads:off -d:release", "tests/test_duplicates")
  run("--threads:on -d:release", "tests/test_duplicates")

  #Also iterate over every test in tests/fail, and verify they fail to compile.
  echo "\r\nTest Fail to Compile:"
  for path in listFiles(thisDir() / "tests" / "fail"):
    if path.split(".")[^1] != "nim":
      continue

    if gorgeEx("nim c " & path).exitCode != 0:
      echo "  [OK] ", path.split(DirSep)[^1]
    else:
      echo "  [FAILED] ", path.split(DirSep)[^1]
      quit(QuitFailure)
