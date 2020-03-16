import std/[net, parseutils]
export net

func parseCmdArg*(T: type IpAddress, s: TaintedString): T =
  parseIpAddress(string s)

proc completeCmdArg*(T: type IpAddress, val: TaintedString): seq[string] =
  # TODO: Maybe complete the local IP address?
  return @[]

func parseCmdArg*(T: type Port, s: TaintedString): T =
  template fail =
    raise newException(ValueError,
      "The supplied port must be an integer value in the range 0-65535")

  var intVal: int
  let parsedChars = try: parseInt(string s, intVal):
                    except CatchableError: fail()

  if parsedChars != len(s) or intVal < 0 or intVal > 65535:
    fail()

  return Port(intVal)

proc completeCmdArg*(T: type Port, val: TaintedString): seq[string] =
  return @[]

