import std/parseutils
import stew/shims/net as stewNet
export stewNet

export ValidIpAddress

func parseCmdArg*(T: type ValidIpAddress, s: TaintedString): T =
  ValidIpAddress.init(string s)

proc completeCmdArg*(T: type ValidIpAddress, val: TaintedString): seq[string] =
  # TODO: Maybe complete the local IP address?
  return @[]

func parseCmdArg*(T: type Port, s: TaintedString): T =
  template fail =
    raise newException(ValueError,
      "The supplied port must be an integer value in the range 1-65535")

  var intVal: int
  let parsedChars = try: parseInt(string s, intVal):
                    except CatchableError: fail()

  if parsedChars != len(s) or intVal < 1 or intVal > 65535:
    fail()

  return Port(intVal)

proc completeCmdArg*(T: type Port, val: TaintedString): seq[string] =
  return @[]

