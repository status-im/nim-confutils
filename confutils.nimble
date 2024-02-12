# confutils
# Copyright (c) 2018-2024 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import os, strutils
mode = ScriptMode.Verbose

packageName   = "confutils"
version       = "0.1.0"
author        = "Status Research & Development GmbH"
description   = "Simplified handling of command line options and config files"
license       = "Apache License 2.0"
skipDirs      = @["tests"]

requires "nim >= 1.6.0",
         "stew",
         "serialization"

let nimc = getEnv("NIMC", "nim") # Which nim compiler to use
let lang = getEnv("NIMLANG", "c") # Which backend (c/cpp/js)
let flags = getEnv("NIMFLAGS", "") # Extra flags for the compiler
let verbose = getEnv("V", "") notin ["", "0"]

let cfg =
  " --styleCheck:usages --styleCheck:error" &
  (if verbose: "" else: " --verbosity:0 --hints:off") &
  " --skipParentCfg --skipUserCfg --outdir:build --nimcache:build/nimcache -f"

proc build(args, path: string) =
  exec nimc & " " & lang & " " & cfg & " " & flags & " " & args & " " & path

proc run(args, path: string) =
  build args & " -r", path
  if (NimMajor, NimMinor) > (1, 6):
    build args & " --mm:refc -r", path

task test, "Run all tests":
  for threads in ["--threads:off", "--threads:on"]:
    run threads, "tests/test_all"
    build threads, "tests/test_duplicates"

  #Also iterate over every test in tests/fail, and verify they fail to compile.
  echo "\r\nTest Fail to Compile:"
  for path in listFiles(thisDir() / "tests" / "fail"):
    if path.split(".")[^1] != "nim":
      continue

    if gorgeEx(nimc & " " & lang & " " & flags & " " & path).exitCode != 0:
      echo "  [OK] ", path.split(DirSep)[^1]
    else:
      echo "  [FAILED] ", path.split(DirSep)[^1]
      quit(QuitFailure)
