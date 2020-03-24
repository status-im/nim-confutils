mode = ScriptMode.Verbose

packageName   = "confutils"
version       = "0.1.0"
author        = "Status Research & Development GmbH"
description   = "Simplified handling of command line options and config files"
license       = "Apache License 2.0"
skipDirs      = @["tests"]

requires "nim >= 1.0.0",
         "stew",
         "testutils"

task test, "run CPU tests":
  when defined(windows):
    exec "cmd.exe /C testrunner.cmd tests"
  else:
    exec "testrunner tests"

