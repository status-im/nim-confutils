# confutils
# Copyright (c) 2018-2025 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  std/[os, osproc, strutils],
  unittest2,
  stew/byteutils,
  ../confutils

const helpPath = "tests" / "help"
const snapshotsPath = helpPath / "snapshots"

func normalizeHelp(s: string): string =
  s.replace("\x1B[0m", "")
    .replace("\r\n", "\n")
    .strip(leading = false)

func cmdsToName(cmds: string): string =
  if cmds.len == 0:
    ""
  else:
    "_" & cmds.replace(" ", "_")

func helpToName(help: string): string =
  help.replace(":", "_")

proc cmdTest(cmdName: string, cmds = "", help = "") =
  let fname = helpPath / cmdName
  var build = "nim c --verbosity:0 --hints:off -d:confutilsNoColors"
  if NimMajor < 2:
    build.add " -d:nimOldCaseObjects"
  let buildRes = execCmdEx(build & " " & fname & ".nim")
  if buildRes.exitCode != 0:
    checkpoint "Build output: " & buildRes.output
    fail()
  else:
    let res = execCmdEx(fname & " " & cmds & " --help" & help)
    let output = res.output.normalizeHelp()
    let snapshot = snapshotsPath / cmdName & cmds.cmdsToName() & help.helpToName() & ".txt"
    if res.exitCode != 0:
      checkpoint "Run output: " & res.output
      fail()
    elif not fileExists(snapshot):
      writeFile(snapshot, output)
      checkpoint "Snapshot created: " & snapshot
      fail()
    else:
      let expected = readFile(snapshot).normalizeHelp()
      checkpoint "Cmd output: " & $output.toBytes()
      checkpoint "Snapshot: " & $expected.toBytes()
      check output == expected

suite "test --help":
  test "test test_nested_cmd":
    cmdTest("test_nested_cmd", "")

  test "test test_nested_cmd lvl1Cmd1":
    cmdTest("test_nested_cmd", "lvl1Cmd1")

  test "test test_nested_cmd lvl1Cmd1 lvl2Cmd2":
    cmdTest("test_nested_cmd", "lvl1Cmd1 lvl2Cmd2")

  test "test test_argument":
    cmdTest("test_argument", "")

  test "test test_argument_abbr":
    cmdTest("test_argument_abbr", "")

  test "test test_default_value_desc":
    cmdTest("test_default_value_desc", "")

  test "test test_separator":
    cmdTest("test_separator", "")

  test "test test_longdesc":
    cmdTest("test_longdesc", "")

  test "test test_longdesc lvl1Cmd1":
    cmdTest("test_longdesc", "lvl1Cmd1")

  test "test test_case_opt":
    cmdTest("test_case_opt", "")

  test "test test_case_opt cmdBlockProcessing":
    cmdTest("test_case_opt", "cmdBlockProcessing")

  test "test test_builtins":
    cmdTest("test_builtins", "")

  test "test test_builtins lvl1Cmd1":
    cmdTest("test_builtins", "lvl1Cmd1")

  test "test test_debug --help":
    cmdTest("test_debug", "")

  test "test test_debug --help:debug":
    cmdTest("test_debug", "", ":debug")

  test "test test_debug lvl1Cmd1 --help:debug":
    cmdTest("test_debug", "lvl1Cmd1", ":debug")

  test "test test_dispatch":
    cmdTest("test_dispatch", "")

  test "test test_default_cmd_desc":
    cmdTest("test_default_cmd_desc", "")

  test "test test_default_cmd_desc exportCommand":
    cmdTest("test_default_cmd_desc", "exportCommand")

  test "test test_default_cmd_desc printCommand":
    cmdTest("test_default_cmd_desc", "printCommand")

  when NimMajor >= 2:
    test "test test_default_cmd_desc_lines":
      cmdTest("test_default_cmd_desc_lines", "")
