# confutils
# Copyright (c) 2018-2025 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import os
import ../../confutils

const defaultEth2TcpPort = 9000
const defaultDescOverride = "ok"

type DisString = distinct string
type NoDollar = distinct string

proc `$`(s: DisString): string =
  # this should show in the help message
  "ok"

proc completeCmdArg(T: type DisString, val: string): seq[string] =
  completeCmdArg(string, val)

proc parseCmdArg(T: type DisString, s: string): T =
  parseCmdArg(string, s).DisString

proc completeCmdArg(T: type NoDollar, val: string): seq[string] =
  completeCmdArg(string, val)

proc parseCmdArg(T: type NoDollar, s: string): T =
  parseCmdArg(string, s).NoDollar

proc runtimeVal(): string =
  # do something that's not available at comptime
  {.cast(raises: []).}:
    discard getCurrentProcessId()
  "ok"

proc canRaise(): string {.raises: [ValueError].} =
  # do something that's not available at comptime
  if false:
    raise (ref ValueError)(msg: "never raised")
  "bad"

type
  TestConf = object
    opt1 {.
      defaultValue: defaultEth2TcpPort
      defaultValueDesc: $defaultEth2TcpPort
      desc: "tcp port"
      name: "opt1" }: int

    opt2 {.
      defaultValue: defaultEth2TcpPort
      desc: "tcp port 2"
      name: "opt2" }: int

    opt3 {.
      defaultValue: "bad"
      defaultValueDesc: defaultDescOverride
      desc: "const default value desc"
      name: "opt3" }: string

    opt4 {.
      defaultValue: "bad"
      defaultValueDesc: "ok"
      desc: "literal default value desc"
      name: "opt4" }: string

    opt5 {.
      defaultValue: DisString("bad")
      desc: "distinct string"
      name: "opt5" }: DisString

    opt6 {.
      defaultValue: NoDollar("default")
      desc: "no dollar func defined"
      name: "opt6" }: NoDollar

    opt7 {.
      defaultValue: NoDollar("bad")
      defaultValueDesc: "ok"
      desc: "no dollar func defined with default desc"
      name: "opt7" }: NoDollar

    opt8 {.
      defaultValue: runtimeVal()
      desc: "runtime value"
      name: "opt8" }: string

    opt9 {.
      defaultValue: "bad"
      defaultValueDesc: runtimeVal()
      desc: "runtime value"
      name: "opt9" }: string

    opt10 {.
      defaultValue: "bad"
      defaultValueDesc: runtimeVal() & " concat"
      desc: "runtime value"
      name: "opt10" }: string

    opt11 {.
      defaultValue: canRaise()
      defaultValueDesc: "ok"
      desc: "default value can raise but default desc won't"
      name: "opt11" }: string

    opt12 {.
      defaultValue: config.opt11
      desc: "default is config.opt11"
      name: "opt12" }: string

    opt13 {.
      defaultValue: config.opt11
      defaultValueDesc: "ok"
      desc: "default is config.opt11 with default desc"
      name: "opt13" }: string

let c = TestConf.load(termWidth = int.high)
