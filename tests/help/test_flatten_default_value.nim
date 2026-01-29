# confutils
# Copyright (c) 2018-2025 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import ../../confutils

const intConst = 9000
const strConst = "abc"

proc strProc: string {.compileTime.} = "abc"
template strTpl: untyped = "abc"

type
  TestOptsConf = object
    opt1 {.
      defaultValue: 123
      defaultValueDesc: "123"
      desc: "some int"
      name: "opt1" }: int

    opt2 {.
      defaultValue: 123
      desc: "some int"
      name: "opt2" }: int

    opt3 {.
      defaultValue: "xyz"
      desc: "some str"
      name: "opt3" }: string

    opt4 {.
      defaultValue: "xyz"
      desc: "some str"
      name: "opt4" }: string

    opt5 {.
      defaultValue: "xyz"
      desc: "some str"
      name: "opt5" }: string

  TestConf = object
    opts {.flatten: (
        opt1: intConst,
        opt2: 8000,
        opt3: strConst,
        opt4: strProc(),
        opt5: strTpl()
      ).}: TestOptsConf

let c = TestConf.load(termWidth = int.high)
