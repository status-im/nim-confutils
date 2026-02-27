# confutils
# Copyright (c) 2018-2025 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import ../../confutils

const defaultEth2TcpPort = 9000
const defaultDescOverride = "overridden"

type DisString = distinct string

proc `$`(s: DisString): string =
  # this should show in the help message
  "foobar"

proc completeCmdArg(T: type DisString, val: string): seq[string] =
  completeCmdArg(string, val)

proc parseCmdArg(T: type DisString, s: string): T =
  parseCmdArg(string, s).DisString

type
  TestConf = object
    opt1 {.
      defaultValue: defaultEth2TcpPort
      defaultValueDesc: $defaultEth2TcpPort
      desc: "tcp port"
      name: "opt1" }: int

    opt2 {.
      defaultValue: defaultEth2TcpPort
      #defaultValueDesc: $defaultEth2TcpPort
      desc: "tcp port 2"
      name: "opt2" }: int

    opt3 {.
      defaultValue: defaultEth2TcpPort
      defaultValueDesc: defaultDescOverride
      desc: "tcp port 3"
      name: "opt3" }: int

    opt4 {.
      defaultValue: defaultEth2TcpPort
      defaultValueDesc: "overridden"
      desc: "tcp port 4"
      name: "opt4" }: int

    opt5 {.
      defaultValue: DisString("this should not show in the help message")
      desc: "distinct string"
      name: "opt5" }: DisString

let c = TestConf.load(termWidth = int.high)
