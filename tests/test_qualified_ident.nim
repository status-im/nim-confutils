import
  std/[strutils, unittest],
  ../confutils,
  ./specialint

type
  TestConf* = object
    La1* {.
      desc: "La1"
      name: "la1" }: SInt

    La2* {.
      desc: "La2"
      name: "la2" }: specialint.SInt

func parseCmdArg(T: type specialint.SInt, p: string): T =
  parseInt(string p).T

func completeCmdArg(T: type specialint.SInt, val: string): seq[string] =
  @[]

suite "Qualified Ident":
  test "Qualified Ident":
    let conf = TestConf.load(@["--la1:123", "--la2:456"])
    check conf.La1.int == 123
    check conf.La2.int == 456
