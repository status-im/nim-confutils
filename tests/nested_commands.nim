import
  confutils, options

type
  OuterCmd = enum
    outerCmd1
    outerCmd2

  InnerCmd = enum
    innerCmd1
    innerCmd2

  Conf = object
    commonOptional: Option[string]
    commonMandatory: int
    case cmd: OuterCmd
    of outerCmd1:
      case innerCmd: InnerCmd
      of innerCmd1:
        ic1Mandatory: string
        ic1Optional: Option[int]
      else:
        discard
    of outerCmd2:
      oc2Mandatory: int

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

