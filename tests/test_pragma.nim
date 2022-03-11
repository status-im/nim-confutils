import
  std/unittest,
  ../confutils,
  ../confutils/defs

{.pragma: customPragma, hidden.}

type
  TestConf* = object
    statusBarEnabled* {.
      customPragma
      desc: "Display a status bar at the bottom of the terminal screen"
      defaultValue: true
      name: "status-bar" }: bool

    statusBarEnabled2* {.
      customPragma
      desc: "Display a status bar at the bottom of the terminal screen"
      defaultValue: true
      name: "status-bar2" }: bool

suite "test custom pragma":
  test "funny AST when called twice":
    let conf = TestConf.load()
    doAssert(conf.statusBarEnabled == true)
    doAssert(conf.statusBarEnabled2 == true)

