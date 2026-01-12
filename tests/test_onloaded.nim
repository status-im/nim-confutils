import
  unittest2,
  ../confutils

type
  TestConf = object
    opt1 {.
      defaultValue: "opt1 default"
      name: "opt1"}: string

var registry {.threadvar.}: seq[string]

suite "test onLoaded parameter":
  test "the onloaded callback is called":
    proc onLoaded(c: var TestConf) =
      doAssert c.opt1 == "opt1 default"
      registry.add "called"

    registry.setLen 0
    let conf = TestConf.load(onLoaded = onLoaded)
    check conf.opt1 == "opt1 default"
    check registry == @["called"]

  test "modify the config var":
    proc onLoaded(c: var TestConf) =
      doAssert c.opt1 == "foo"
      c.opt1 = "foo modified"
      registry.add "modified"

    registry.setLen 0
    let conf = TestConf.load(
      cmdLine = @[
        "--opt1=foo"
      ],
      onLoaded = onLoaded
    )
    check conf.opt1 == "foo modified"
    check registry == @["modified"]

  test "use a callback closure":
    var message = "closure"
    proc onLoaded(c: var TestConf) {.closure.} =
      doAssert c.opt1 == "opt1 default"
      registry.add message

    registry.setLen 0
    let conf = TestConf.load(onLoaded = onLoaded)
    check conf.opt1 == "opt1 default"
    check registry == @["closure"]
