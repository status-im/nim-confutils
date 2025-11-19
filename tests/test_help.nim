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

proc cmdTest(cmdName: string, cmds = "") =
  let fname = helpPath / cmdName
  var build = "nim c --verbosity:0 --hints:off -d:confutilsNoColors"
  if NimMajor < 2:
    build.add " -d:nimOldCaseObjects"
  let buildRes = execCmdEx(build & " " & fname & ".nim")
  if buildRes.exitCode != 0:
    checkpoint "Build output: " & buildRes.output
    fail()
  else:
    let res = execCmdEx(fname & " " & cmds & " --help")
    let output = res.output.normalizeHelp()
    let snapshot = snapshotsPath / cmdName & cmds.cmdsToName() & ".txt"
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
