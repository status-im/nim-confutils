import
  os, parseopt, strutils, options, std_shims/macros_shim, typetraits, terminal,
  confutils/defs

export
  defs

type
  CommandDesc = object
    name: string
    options: seq[OptionDesc]
    subCommands: seq[CommandDesc]
    fieldIdx: int
    argumentsFieldIdx: int

  OptionDesc = object
    name, typename, shortform: string
    hasDefault: bool
    rejectNext: bool
    fieldIdx: int
    desc: string

template appName: string =
  getAppFilename().splitFile.name

when not defined(confutils_no_colors):
  template write(args: varargs[untyped]) =
    stdout.styledWrite(args)
else:
  const
    styleBright = ""

  template write(args: varargs[untyped]) =
    stdout.write(args)

proc describeCmdOptions(cmd: CommandDesc) =
  for opt in cmd.options:
    write "  --", opt.name, "=", opt.typename
    if opt.desc.len > 0:
      write repeat(" ", max(0, 40 - opt.name.len - opt.typename.len)), ": ", opt.desc
    write "\n"

proc showHelp(cmd: CommandDesc) =
  let app = appName

  write "Usage: ", styleBright, app
  if cmd.name.len > 0: write " ", cmd.name
  if cmd.options.len > 0: write " [OPTIONS]"
  if cmd.subCommands.len > 0: write " <command>"
  if cmd.argumentsFieldIdx != -1: write " [<args>]"

  if cmd.options.len > 0:
    write "\n\nThe following options are supported:\n\n"
    describeCmdOptions(cmd)

  if cmd.subCommands.len > 0:
    write "\nAvailable sub-commands:\n\n"
    for subcmd in cmd.subCommands:
      write "  ", styleBright, app, " ", subcmd.name, "\n\n"
      describeCmdOptions(subcmd)

  write "\n"
  quit(0)

proc parseCmdArg*(T: type DirPath, p: TaintedString): T =
  # TODO: check existence
  result = DirPath(p)

proc parseCmdArg*(T: type OutFilePath, p: TaintedString): T =
  # TODO: warn the user on rewrites
  result = OutFilePath(p)

proc parseCmdArg*(T: type FilePath, p: TaintedString): T =
  # TODO: check existence
  result = FilePath(p)

proc parseCmdArg*[T](_: type Option[T], s: TaintedString): Option[T] =
  return some(parseCmdArg(T, s))

template parseCmdArg*(T: type string, s: TaintedString): string =
  string s

proc parseCmdArg*(T: type SomeSignedInt, s: TaintedString): T =
  T parseInt(string s)

proc parseCmdArg*(T: type SomeUnsignedInt, s: TaintedString): T =
  T parseUInt(string s)

proc parseCmdArg*(T: type SomeFloat, p: TaintedString): T =
  result = parseFloat(p)

proc parseCmdArg*(T: type bool, p: TaintedString): T =
  result = parseBool(p)

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

proc requiresInput*(T: type): bool =
  result = not ((T is seq) or (T is Option))

# TODO: The usage of this should be replacable with just `type(x)`,
# but Nim is not able to handle it at the moment.
macro typeof(x: typed): untyped =
  result = x.getType

template debugMacroResult(macroName: string) {.dirty.} =
  when defined(debugMacros) or defined(debugConfutils):
    echo "\n-------- ", macroName, " ----------------------"
    echo result.repr

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

      # TODO: This shouldn't be necessary. The type symbol returned from Nim should
      # be typed as a tyTypeDesc[tyString] instead of just `tyString`. To be filed.
      var fixedFieldType = newTree(nnkTypeOfExpr, field.typ)

      settersArray.add newTree(nnkTupleConstr,
                               newCall(bindSym"FieldSetter", setterName),
                               newCall(bindSym"requiresInput", fixedFieldType))

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
    debugMacroResult "Field Setters"

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
        option.hasDefault = hasDefault
        option.typename = field.typ.repr
        if desc != nil: option.desc = desc.strVal
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
    debugMacroResult "Command Tree"

  let fieldSetters = generateFieldSetters(Configuration)
  var rootCmd = buildCommandTree(Configuration)

  proc fail(msg: string) =
    if quitOnFailure:
      stderr.writeLine(msg)
      stderr.writeLine("Try '{1} --help' for more information" % appName)
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

  template required(opt: OptionDesc): bool =
    fieldSetters[opt.fieldIdx][1] and not opt.hasDefault

  proc processMissingOptions(conf: var Configuration, cmd: ptr CommandDesc) =
    for o in cmd.options:
      if o.rejectNext == false:
        if o.required:
          fail "The required option '$1' was not specified" % [o.name]
        elif o.hasDefault:
          discard fieldSetters[o.fieldIdx][0](conf, TaintedString(""))

  var currentCmd = addr rootCmd
  var rejectNextArgument = currentCmd.argumentsFieldIdx == -1

  for kind, key, val in getopt(cmdLine):
    case kind
    of cmdLongOption, cmdShortOption:
      if string(key) == "help":
        showHelp currentCmd[]

      let option = currentCmd.findOption(key)
      if option != nil:
        if option.rejectNext:
          fail "The options '$1' should not be specified more than once" % [string(key)]
        option.rejectNext = fieldSetters[option.fieldIdx][0](result, val)
      else:
        fail "Unrecognized option '$1'" % [string(key)]

    of cmdArgument:
      if string(key) == "help" and currentCmd.subCommands.len > 0:
        showHelp currentCmd[]

      let subCmd = currentCmd.findSubcommand(key)
      if subCmd != nil:
        discard fieldSetters[subCmd.fieldIdx][0](result, key)
        currentCmd = subCmd
        rejectNextArgument = currentCmd.argumentsFieldIdx == -1
      else:
        if rejectNextArgument:
          fail "The command '$1' does not accept additional arguments" % [currentCmd.name]
        let argumentIdx = currentCmd.argumentsFieldIdx
        doAssert argumentIdx != -1
        rejectNextArgument = fieldSetters[argumentIdx][0](result, key)

    else:
      discard

  result.processMissingOptions(currentCmd)

proc dispatchImpl(cliProcSym, cliArgs, loadArgs: NimNode): NimNode =
  # Here, we'll create a configuration object with fields matching
  # the CLI proc params. We'll also generate a call to the designated
  # p
  let configType = genSym(nskType, "CliConfig")
  let configFields = newTree(nnkRecList)
  let configVar = genSym(nskLet, "config")
  var dispatchCall = newCall(cliProcSym)

  # The return type of the proc is skipped over
  for i in 1 ..< cliArgs.len:
    var arg = copy cliArgs[i]

    # If an argument doesn't specify a type, we infer it from the default value
    if arg[1].kind == nnkEmpty:
      if arg[2].kind == nnkEmpty:
        error "Please provide either a default value or type of the parameter", arg
      arg[1] = newCall(bindSym"typeof", arg[2])

    # Turn any default parameters into the confutils's `defaultValue` pragma
    if arg[2].kind != nnkEmpty:
      if arg[0].kind != nnkPragmaExpr:
        arg[0] = newTree(nnkPragmaExpr, arg[0], newTree(nnkPragma))
      arg[0][1].add newColonExpr(bindSym"defaultValue", arg[2])
      arg[2] = newEmptyNode()

    configFields.add arg
    dispatchCall.add newTree(nnkDotExpr, configVar, skipPragma arg[0])

  let cliConfigType = nnkTypeSection.newTree(
    nnkTypeDef.newTree(
      configType,
      newEmptyNode(),
      nnkObjectTy.newTree(
        newEmptyNode(),
        newEmptyNode(),
        configFields)))

  var loadConfigCall = newCall(bindSym"load", configType)
  for p in loadArgs: loadConfigCall.add p

  result = quote do:
    `cliConfigType`
    let `configVar` = `loadConfigCall`
    `dispatchCall`

macro dispatch*(fn: typed, args: varargs[untyped]): untyped =
  if fn.kind != nnkSym or
     fn.symKind notin {nskProc, nskFunc, nskMacro, nskTemplate}:
    error "The first argument to `confutils.dispatch` should be a callable symbol"

  let fnImpl = fn.getImpl
  result = dispatchImpl(fnImpl.name, fnImpl.params, args)
  debugMacroResult "Dispatch Code"

macro cli*(args: varargs[untyped]): untyped =
  if args.len == 0:
    error "The cli macro expects a do block", args

  let doBlock = args[^1]
  if doBlock.kind notin {nnkDo, nnkLambda}:
    error "The last argument to `confutils.cli` should be a do block", doBlock

  args.del(args.len - 1)

  # Create a new anonymous proc we'll dispatch to
  let cliProcName = genSym(nskProc, "CLI")
  var cliProc = newTree(nnkProcDef, cliProcName)
  # Copy everything but the name from the do block:
  for i in 1 ..< doBlock.len: cliProc.add doBlock[i]

  # Generate the final code
  result = newStmtList(cliProc, dispatchImpl(cliProcName, cliProc.params, args))

  # TODO: remove this once Nim supports custom pragmas on proc params
  for p in cliProc.params:
    if p.kind == nnkEmpty: continue
    p[0] = skipPragma p[0]

  debugMacroResult "CLI Code"

