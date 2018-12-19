import
  os, parseopt, strutils, std_shims/macros_shim, typetraits, confutils/defs

export
  defs

proc parseCmdArg*(T: type DirPath, p: TaintedString): T =
  result = DirPath(p)

proc parseCmdArg*(T: type OutFilePath, p: TaintedString): T =
  result = OutFilePath(p)

template parseCmdArg*(T: type string, s: TaintedString): string =
  string s

proc parseCmdArg*(T: type SomeSignedInt, s: TaintedString): T =
  T parseInt(string s)

proc parseCmdArg*(T: type SomeUnsignedInt, s: TaintedString): T =
  T parseUInt(string s)

proc parseCmdArg*(T: type enum, s: TaintedString): T =
  parseEnum[T](string(s))

template setField[T](loc: var T, val: TaintedString, defaultVal: untyped): bool =
  mixin parseCmdArg
  type FieldType = type(loc)

  loc = if len(val) > 0: parseCmdArg(FieldType, val)
        else: FieldType(defaultVal)
  true

template setField[T](loc: var seq[T], val: TaintedString, defaultVal: untyped): bool =
  mixin parseCmdArg
  loc.add parseCmdArg(type(loc[0]), val)
  false

template simpleSet(loc: var auto) =
  discard

proc makeDefaultValue*(T: type): T =
  discard

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

  mixin parseCmdArg

  type
    FieldSetter = proc (cfg: var Configuration, val: TaintedString): bool {.nimcall.}

    CommandDesc = object
      name: string
      options: seq[OptionDesc]
      subCommands: seq[CommandDesc]
      fieldIdx: int
      argumentsFieldIdx: int

    OptionDesc = object
      name, typename, shortform: string
      required: bool
      rejectNext: bool
      fieldIdx: int

  template readPragma(field, name): NimNode =
    let p = field.pragmas.findPragma bindSym(name)
    if p != nil and p.len == 2: p[1] else: p

  macro generateFieldSetters(RecordType: type): untyped =
    var recordDef = RecordType.getType[1].getImpl
    let makeDefaultValue = bindSym"makeDefaultValue"

    result = newTree(nnkStmtListExpr)
    var settersArray = newTree(nnkBracket)

    for field in recordFields(recordDef):
      var
        setterName = ident($field.name & "Setter")
        fieldName = field.name
        recordVar = ident "record"
        recordField = newTree(nnkDotExpr, recordVar, fieldName)
        defaultValue = field.readPragma"defaultValue"

      if defaultValue == nil:
        defaultValue = newCall(makeDefaultValue, newTree(nnkTypeOfExpr, recordField))

      settersArray.add newCall(bindSym"FieldSetter", setterName)

      result.add quote do:
        proc `setterName`(`recordVar`: var `RecordType`, val: TaintedString): bool {.nimcall.} =
          when `recordField` is enum:
            # TODO: For some reason, the normal `setField` rejects enum fields
            # when they are used as case discriminators. File this as a bug.
            `recordField` = parseEnum[type(`recordField`)](string(val))
            return true
          else:
            return setField(`recordField`, val, `defaultValue`)

    result.add settersArray

  macro buildCommandTree(RecordType: type): untyped =
    var recordDef = RecordType.getType[1].getImpl
    var res: CommandDesc
    res.argumentsFieldIdx = -1

    var fieldIdx = 0
    for field in recordFields(recordDef):
      let
        isCommand = field.readPragma"command" != nil
        hasDefault = field.readPragma"defaultValue" != nil
        shortform = field.readPragma"shortform"
        longform = field.readPragma"longform"
        desc = field.readPragma"desc"

      if isCommand:
        let cmdType = field.typ.getImpl[^1]
        if cmdType.kind != nnkEnumTy:
          error "The command pragma should be specified only on enum fields", field.name
        for i in 2 ..< cmdType.len:
          res.subCommands.add CommandDesc(name: $cmdType[i],
                                          fieldIdx: fieldIdx,
                                          argumentsFieldIdx: -1)
      else:
        var option: OptionDesc
        option.fieldIdx = fieldIdx
        option.name = $field.name
        option.required = not hasDefault
        option.typename = field.typ.repr
        if longform != nil: option.name = longform.strVal
        if shortform != nil: option.shortform = shortform.strVal

        var isSubcommandOption = false
        if field.caseBranch != nil:
          let branchCmd = $field.caseBranch[0]
          for cmd in mitems(res.subCommands):
            if cmd.name == branchCmd:
              cmd.options.add option
              isSubcommandOption = true
              break

        if not isSubcommandOption:
          res.options.add option

      inc fieldIdx

    result = newLitFixed(res)

  let fieldSetters = generateFieldSetters(Configuration)
  var rootCmd = buildCommandTree(Configuration)

  proc fail(msg: string) =
    if quitOnFailure:
      stderr.writeLine(msg)
      quit 1
    else:
      raise newException(ConfigurationError, msg)

  proc findOption(cmd: ptr CommandDesc, name: TaintedString): ptr OptionDesc =
    for o in cmd.options.mitems:
      if cmpIgnoreStyle(o.name, string(name)) == 0 or
         cmpIgnoreStyle(o.shortform, string(name)) == 0:
        return addr(o)

    return nil

  proc findSubcommand(cmd: ptr CommandDesc, name: TaintedString): ptr CommandDesc =
    for subCmd in cmd.subCommands.mitems:
      if cmpIgnoreStyle(subCmd.name, string(name)) == 0:
        return addr(subCmd)

    return nil

  proc checkForMissingOptions(cmd: ptr CommandDesc) =
    for o in cmd.options:
      if o.required and o.rejectNext == false:
        fail "The required option '$1' was not specified" % [o.name]

  var currentCmd = addr rootCmd
  var rejectNextArgument = currentCmd.argumentsFieldIdx == -1

  for kind, key, val in getopt(cmdLine):
    case kind
    of cmdLongOption, cmdShortOption:
      let option = currentCmd.findOption(key)
      if option != nil:
        if option.rejectNext:
          fail "The options '$1' should not be specified more than once" % [string(key)]
        option.rejectNext = fieldSetters[option.fieldIdx](result, val)
      else:
        fail "Unrecognized option '$1'" % [string(key)]

    of cmdArgument:
      let subCmd = currentCmd.findSubcommand(key)
      if subCmd != nil:
        discard fieldSetters[subCmd.fieldIdx](result, key)
        currentCmd = subCmd
        rejectNextArgument = currentCmd.argumentsFieldIdx == -1
      else:
        if rejectNextArgument:
          fail "The command '$1' does not accept additional arguments" % [currentCmd.name]
        let argumentIdx = currentCmd.argumentsFieldIdx
        doAssert argumentIdx != -1
        rejectNextArgument = fieldSetters[argumentIdx](result, key)

    else:
      discard

  currentCmd.checkForMissingOptions()

