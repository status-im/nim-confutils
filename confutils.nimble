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
version       = "0.1.1"
author        = "Status Research & Development GmbH"
description   = "Simplified handling of command line options and config files"
license       = "Apache License 2.0"
skipDirs      = @["tests"]

requires "nim >= 2.0.10",
         "stew >= 0.5.0",
         "serialization >= 0.5.4",
         "results >= 0.5.0"

let nimc = getEnv("NIMC", "nim") # Which nim compiler to use
let lang = getEnv("NIMLANG", "c") # Which backend (c/cpp/js)
let flags = getEnv("NIMFLAGS", "") # Extra flags for the compiler
let verbose = getEnv("V", "") notin ["", "0"]
let platform = getEnv("PLATFORM", "")

let cfg =
  " --styleCheck:usages --styleCheck:error" &
  (if verbose: "" else: " --verbosity:0") &
  " --skipParentCfg --skipUserCfg --outdir:build -f " &
  quoteShell("--nimcache:build/nimcache/$projectName")

proc build(args, path: string) =
  exec nimc & " " & lang & " " & cfg & " " & flags & " " & args & " " & path

proc run(args, path: string) =
  build args & " -r", path

task test, "Run all tests":
  for threads in ["--threads:off", "--threads:on"]:
    for mm in ["--mm:refc", "--mm:orc"]:
      run threads & " " & mm, "tests/test_all"
      run threads & " " & mm, "confutils/shell_completion"
    build threads, "tests/test_duplicates"

  #Also iterate over every test in tests/fail, and verify they fail to compile.
  echo "\r\nTest Fail to Compile:"
  for path in listFiles(thisDir() / "tests" / "fail"):
    if not path.endsWith(".nim"):
      continue
    if gorgeEx(nimc & " " & lang & " " & flags & " " & path).exitCode != 0:
      echo "  [OK] ", path.split(DirSep)[^1]
    else:
      echo "  [FAILED] ", path.split(DirSep)[^1]
      quit(QuitFailure)

  echo "\r\nNimscript test:"
  let
    actualOutput = gorgeEx(
      nimc & " --verbosity:0 e " & flags & " " & "./tests/cli_example.nim " &
      "--foo=1 --bar=2 --withBaz 42").output
    expectedOutput = unindent"""
      foo = 1
      bar = 2
      baz = true
      arg 42"""
  if actualOutput.strip() == expectedOutput:
    echo "  [OK] tests/cli_example.nim"
  else:
    echo "  [FAILED] tests/cli_example.nim"
    echo actualOutput
    quit(QuitFailure)

task test_asan, "Run all tests with ASAN":
  if platform != "x86":
    # https://clang.llvm.org/docs/AddressSanitizer.html
    putEnv("ASAN_OPTIONS", "detect_leaks=0:detect_stack_use_after_return=1")
    # https://clang.llvm.org/docs/UndefinedBehaviorSanitizer.html
    putEnv("UBSAN_OPTIONS", "print_stacktrace=1")
    let asanArgs =
      " --mm:orc -d:useMalloc --cc:clang --debugger:native" &
      " --passC:-fsanitize=address,undefined" &
      " --passL:-fsanitize=address,undefined" &
      " --passC:-fno-sanitize-recover=undefined" &
      " --passC:-fno-sanitize-merge" &
      " --passC:-fno-omit-frame-pointer"
    for threads in ["--threads:off", "--threads:on"]:
      run threads & asanArgs, "tests/test_all"
      run threads & asanArgs, "confutils/shell_completion"
