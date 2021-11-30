import
  std/unittest,
  ../confutils,
  ../confutils/defs

type
  TestConf* = object
    dataDir* {.
      ignore
      defaultValue: "nimbus"
      name: "data-dir"}: string

    logLevel* {.
      defaultValue: "DEBUG"
      desc: "Sets the log level."
      name: "log-level" }: string

suite "test ignore option":
  test "ignored option have no default value":
    let conf = TestConf.load()
    doAssert(conf.logLevel == "DEBUG")
    doAssert(conf.dataDir == "")
