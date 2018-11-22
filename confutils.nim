import
  os, parseopt, strutils, macros, typetraits, confutils/defs

export
  defs

proc parse*(T: type DirPath, p: TaintedString): T =
  result = DirPath(p)

template parse*(T: type string, s: TaintedString): string =
  string s

proc parse*(T: type SomeSignedInt, s: TaintedString): T =
  T parseInt(string s)

proc parse*(T: type SomeUnsignedInt, s: TaintedString): T =
  T parseUInt(string s)

proc load*(Configuration: type,
           cmdLine = commandLineParams(),
           printUsage = true,
           quitOnFailure = true): Configuration =
  ## Loads a program configuration by parsing command-line arguments
  ## and a standard set of config files that can specify:
  ##
  ##  - working directory settings
  ##  - user settings
  ##  - system-wide setttings
  ##
  ##  Supports multiple config files format (INI/TOML, YAML, JSON).

  # This is an initial naive implementation that will be improved
  # over time.

  mixin parse

  type
    FieldSetter = proc (val: TaintedString)

    ParamDesc = object
      name, shorthand: string
      typename: string # this is a human-readable type

      required: bool
      occurances: int
      isSeq: bool

      setter: FieldSetter

  var
    params = newSeq[ParamDesc]()
    requiredFields = 0

  for fieldName, field in fieldPairs(result):
    var param: ParamDesc
    param.name = fieldName

    type FieldType = type(field)

    when field.hasCustomPragma(defaultValue):
      field = FieldType field.getCustomPragmaVal(defaultValue)
    else:
      param.required = true

    when FieldType is seq:
      param.isSeq = true
      param.required = false

    param.typename = FieldType.name

    var fieldAddr = addr(field)
    param.setter = proc (stringValue: TaintedString) =
      when FieldType is seq:
        type ElemType = type(field[0])
        fieldAddr[].add parse(ElemType, stringValue)
      else:
        fieldAddr[] = FieldType.parse(stringValue)

    when field.hasCustomPragma(shorthand):
      param.shorthand = field.getCustomPragmaVal(shorthand)

    params.add param

  proc fail(msg: string) =
    if quitOnFailure:
      stderr.writeLine(msg)
      quit 1
    else:
      raise newException(ConfigurationError, msg)

  proc findParam(name: TaintedString): ptr ParamDesc =
    for p in params.mitems:
      if cmpIgnoreStyle(p.name, string(name)) == 0 or
         cmpIgnoreStyle(p.shorthand, string(name)) == 0:
        return addr(p)

    return nil

  for kind, key, val in getopt(cmdLine):
    if kind in {cmdLongOption, cmdShortOption}:
      let param = findParam(key)
      if param != nil:
        inc param.occurances
        if param.occurances > 1 and not param.isSeq:
          fail "The options '$1' should not be specified more than once" % [string(key)]
        param.setter(val)
      else:
        fail "Unrecognized option '$1'" % [string(key)]

  for p in params:
    if p.required and p.occurances == 0:
      fail "The required option '$1' was not specified" % [p.name]

