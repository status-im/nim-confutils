# confutils
# Copyright (c) 2018-2025 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  std/[os, osproc, strutils, sequtils],
  unittest2,
  stew/byteutils,
  ../confutils

const helpPath = "tests" / "help"
const snapshotsPath = helpPath / "snapshots"

func normalizeHelp(s: string): string =
  s.replace("\x1B[0m", "")
    .replace("\r\n", "\n")
    .replace("\r", "\n")
    .strip(leading = false)

func argsToName(args: string): string =
  if args.len == 0:
    ""
  else:
    "_" & args.replace(" ", "_")

proc cmdTest(cmdName, args: string) =
  let fname = helpPath / cmdName
  if not fileExists(fname):
    var build = "nim c --verbosity:0 --hints:off -d:confutilsNoColors"
    if NimMajor < 2:
      build.add " -d:nimOldCaseObjects"
    let buildRes = execCmdEx(build & " " & fname & ".nim")
    check buildRes.exitCode == 0
  let res = execCmdEx(fname & " " & args & " --help")
  check res.exitCode == 0
  let output = res.output.normalizeHelp()
  let snapshot = snapshotsPath / cmdName & args.argsToName() & ".txt"
  if not fileExists(snapshot):
    writeFile(snapshot, output)
    checkpoint "Snapshot created: " & snapshot
    fail()
  let expected = readFile(snapshot).normalizeHelp()
  checkpoint "Cmd output: " & $output.toBytes()
  checkpoint "Snapshot: " & $expected.toBytes()
  check output == expected

suite "test --help":
  test "test test_nested_cmd default":
    cmdTest("test_nested_cmd", "")

  test "test test_nested_cmd outerCmd1":
    cmdTest("test_nested_cmd", "outerCmd1")
    
