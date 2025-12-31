# nim-confutils
# Copyright (c) 2023 Status Research & Development GmbH
# Licensed and distributed under either of
#   * MIT license: [LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT
#   * Apache License, Version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
# at your option. This file may not be copied, modified, or distributed except according to those terms.

import
  std/[os, strutils],
  unittest2,
  ../confutils

const EnvVarPrefix = "Nimbus"

type
  SomeObject = object
    name: string
    isNice: bool

  TestConf* = object
    logLevel* {.
      defaultValue: "DEBUG"
      desc: "Sets the log level."
      name: "log-level" }: string

    somObject* {.
      desc: "..."
      defaultValue: SomeObject()
      name: "object" }: SomeObject

    dataDir* {.
      defaultValue: ""
      desc: "The directory where nimbus will store all blockchain data"
      abbr: "d"
      name: "data-dir" }: OutDir

func completeCmdArg(T: type SomeObject, val: string): seq[string] =
  @[]

func parseCmdArg(T: type SomeObject, p: string): T =
  let parsedString = p.split('-')
  SomeObject(name:parsedString[0], isNice: parseBool(parsedString[1]))


proc testEnvvar() =
  suite "env var support suite":

    test "env vars are loaded":
      putEnv("NIMBUS_DATA_DIR", "ENV VAR DATADIR")
      let conf = TestConf.load(envVarsPrefix=EnvVarPrefix)
      check conf.dataDir.string == "ENV VAR DATADIR"

    test "env vars do not have priority over cli parameters":
      putEnv("NIMBUS_DATA_DIR", "ENV VAR DATADIR")
      putEnv("NIMBUS_LOG_LEVEL", "ERROR")

      let conf = TestConf.load(@["--log-level=INFO"], envVarsPrefix=EnvVarPrefix)
      check conf.dataDir.string == "ENV VAR DATADIR"
      check conf.logLevel.string == "INFO"

    test "env vars use parseCmdArg":
      putEnv("NIMBUS_OBJECT", "helloObject-true")
      let conf = TestConf.load(envVarsPrefix=EnvVarPrefix)
      check conf.somObject.name.string == "helloObject"
      check conf.somObject.isNice.bool == true

    test "env vars no prefix":
      putEnv("DATA_DIR", "ENV VAR DATADIR")
      let conf = TestConf.load(envVarsPrefix="")
      check conf.dataDir.string == "ENV VAR DATADIR"

testEnvvar()
