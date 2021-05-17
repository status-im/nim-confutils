import
  confutils, options

type
  OuterCmd = enum
    outerCmd1
    outerCmd2
    outerCmd3

  InnerCmd = enum
    innerCmd1 = "Inner cmd 1"
    innerCmd2

  OuterOpt = enum
    outerOpt1 = "Option1"
    outerOpt2 = "Option2"
    outerOpt3 = "Option3"

  InnerOpt = enum
    innerOpt1
    innerOpt2

  Conf = object
    commonOptional: Option[string]
    commonMandatory {.
      desc: "A mandatory option"
      abbr: "m" .}: int

    case opt: OuterOpt
    of outerOpt1:
      case innerOpt: InnerOpt
      of innerOpt1:
        io1Mandatory: string
        io1Optional: Option[int]
      else:
        discard
    of outerOpt2:
      ooMandatory: string
      ooOptiona {.
        defaultValue: "test"
        desc: "Outer option optional" .}: string
    of outerOpt3:
      discard

    case cmd {.command.}: OuterCmd
    of outerCmd1:
      case innerCmd: InnerCmd
      of innerCmd1:
        ic1Mandatory: string
        ic1Optional {.
          desc: "Delay in seconds"
          abbr: "s" .}: Option[int]
      of innerCmd2:
        innerArg {.argument.}: string
    of outerCmd2:
      oc2Mandatory: int
    of outerCmd3:
      x {.argument.}: string
      y {.argument.}: string
      z {.argument.}: string

let conf = load Conf

echo "commonOptional  = ", conf.commonOptional
echo "commonMandatory = ", conf.commonMandatory
case conf.cmd
of outerCmd2:
  echo "oc2Mandatory    = ", conf.oc2Mandatory
of outerCmd1:
  case conf.innerCmd:
  of innerCmd1:
    echo "ic1Mandatory    = ", conf.ic1Mandatory
    echo "ic1Optional     = ", conf.ic1Optional
  of innerCmd2:
    discard
of outerCmd3:
  echo "outer cmd3 ", conf.x, " ", conf.y, " ", conf.z

