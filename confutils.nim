import
  strutils, options, std_shims/macros_shim, typetraits,
  confutils/[defs, cli_parser]

export
  defs

when not defined(nimscript):
  import os, terminal

type
  CommandDesc = ref object
    name: string
    options: seq[OptionDesc]
    subCommands: seq[CommandDesc]
    defaultSubCommand: int
    fieldIdx: int
    argumentsFieldIdx: int

  OptionDesc = ref object
    name, typename, shortform: string
    hasDefault: bool
    rejectNext: bool
    fieldIdx: int
    desc: string

  CommandPtr = CommandDesc
  OptionPtr = OptionDesc

proc newLitFixed*(arg: ref): NimNode {.compileTime.} =
  result = nnkObjConstr.newTree(arg.type.getTypeInst[1])
  for a, b in fieldPairs(arg[]):
    result.add nnkExprColonExpr.newTree( newIdentNode(a), newLitFixed(b) )

when defined(nimscript):
  proc appInvocation: string =
    "nim " & (if paramCount() > 1: paramStr(1) else: "<nims-script>")

  type stderr = object

  template writeLine(T: type stderr, msg: string) =
    echo msg

  proc commandLineParams(): seq[string] =
    for i in 2 .. paramCount():
      result.add paramStr(i)

  # TODO: Why isn't this available in NimScript?
  proc getCurrentExceptionMsg(): string =
    ""

else:
  template appInvocation: string =
    getAppFilename().splitFile.name

when defined(nimscript):
  const styleBright = ""

  # Deal with the issue that `stdout` is not defined in nimscript
  var buffer = ""
  proc write(args: varargs[string, `$`]) =
    for arg in args:
      buffer.add arg
    if args[^1][^1] == '\n':
      buffer.setLen(buffer.len - 1)
      echo buffer
      buffer = ""

elif not defined(confutils_no_colors):
  template write(args: varargs[untyped]) =
    stdout.styledWrite(args)

else:
  const styleBright = ""

  template write(args: varargs[untyped]) =
    stdout.write(args)

template hasArguments(cmd: CommandPtr): bool =
  cmd.argumentsFieldIdx != -1

template isSubCommand(cmd: CommandPtr): bool =
  cmd.name.len > 0

proc noMoreArgumentsError(cmd: CommandPtr): string =
  result = if cmd.isSubCommand: "The command '$1'" % [cmd.name]
           else: appInvocation()
  result.add " does not accept"
  if cmd.hasArguments: result.add " additional"
  result.add " arguments"

proc describeCmdOptions(cmd: CommandDesc) =
  for opt in cmd.options:
    write "  --", opt.name, "=", opt.typename
    if opt.desc.len > 0:
      write repeat(" ", max(0, 40 - opt.name.len - opt.typename.len)), ": ", opt.desc
    write "\n"

proc showHelp(version: string, cmd: CommandDesc) =
  let app = appInvocation()

  write "Usage: ", styleBright, app
  if cmd.name.len > 0: write " ", cmd.name
  if cmd.options.len > 0: write " [OPTIONS]"
  if cmd.subCommands.len > 0: write " <command>"
  if cmd.argumentsFieldIdx != -1: write " [<args>]"

  if cmd.options.len > 0:
    write "\n\nThe following options are supported:\n\n"
    describeCmdOptions(cmd)

  if cmd.defaultSubCommand != -1:
    describeCmdOptions(cmd.subCommands[cmd.defaultSubCommand])

  if cmd.subCommands.len > 0:
    write "\nAvailable sub-commands:\n"
    for i in 0 ..< cmd.subCommands.len:
      if i != cmd.defaultSubCommand:
        write "\n  ", styleBright, app, " ", cmd.subCommands[i].name, "\n\n"
        describeCmdOptions(cmd.subCommands[i])

  write "\n"
  quit(0)

proc findOption(cmds: seq[CommandPtr], name: TaintedString): OptionPtr =
  for i in countdown(cmds.len - 1, 0):
    for o in cmds[i].options.mitems:
      if cmpIgnoreStyle(o.name, string(name)) == 0 or
         cmpIgnoreStyle(o.shortform, string(name)) == 0:
        return o

  return nil

proc findSubcommand(cmd: CommandPtr, name: TaintedString): CommandPtr =
  for subCmd in cmd.subCommands.mitems:
    if cmpIgnoreStyle(subCmd.name, string(name)) == 0:
      return subCmd

  return nil

when defined(debugCmdTree):
  proc printCmdTree(cmd: CommandDesc, indent = 0) =
    let blanks = repeat(' ', indent)
    echo blanks, "> ", cmd.name
    for opt in cmd.options:
      echo blanks, "  - ", opt.name, ": ", opt.typename
    for subcmd in cmd.subCommands:
      printCmdTree(subcmd, indent + 2)
else:
  template printCmdTree(cmd: CommandDesc) = discard

# TODO remove the overloads here to get better "missing overload" error message
proc parseCmdArg*(T: type InputDir, p: TaintedString): T =
  if not dirExists(p.string):
    raise newException(ValueError, "Directory doesn't exist")

  result = T(p)

proc parseCmdArg*(T: type InputFile, p: TaintedString): T =
  # TODO this is needed only because InputFile cannot be made
  # an alias of TypedInputFile at the moment, because of a generics
  # caching issue
  if not fileExists(p.string):
    raise newException(ValueError, "File doesn't exist")

  when not defined(nimscript):
    try:
      let f = open(p.string, fmRead)
      close f
    except IOError:
      raise newException(ValueError, "File not accessible")

  result = T(p.string)

proc parseCmdArg*(T: type TypedInputFile, p: TaintedString): T =
  var path = p.string
  when T.defaultExt.len > 0:
    path = path.addFileExt(T.defaultExt)

  if not fileExists(path):
    raise newException(ValueError, "File doesn't exist")

  when not defined(nimscript):
    try:
      let f = open(path, fmRead)
      close f
    except IOError:
      raise newException(ValueError, "File not accessible")

  result = T(path)

proc parseCmdArg*(T: type[OutDir|OutFile|OutPath], p: TaintedString): T =
  result = T(p)

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

proc parseCmdArgAux(T: type, s: TaintedString): T = # {.raises: [ValueError].} =
  # The parseCmdArg procs are allowed to raise only `ValueError`.
  # If you have provided your own specializations, please handle
  # all other exception types.
  mixin parseCmdArg
  parseCmdArg(T, s)

template setField[T](loc: var T, val: TaintedString, defaultVal: untyped): bool =
  type FieldType = type(loc)
  loc = if len(val) > 0: parseCmdArgAux(FieldType, val)
        else: FieldType(defaultVal)
  true

template setField[T](loc: var seq[T], val: TaintedString, defaultVal: untyped): bool =
  loc.add parseCmdArgAux(type(loc[0]), val)
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
           version = "",
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

  type
    FieldSetter = proc (cfg: var Configuration, val: TaintedString): bool {.nimcall.}

  macro generateFieldSetters(RecordType: type): untyped =
    var recordDef = RecordType.getType[1].getImpl
    let makeDefaultValue = bindSym"makeDefaultValue"

    result = newTree(nnkStmtListExpr)
    var settersArray = newTree(nnkBracket)

    for field in recordFields(recordDef):
      var
        setterName = ident($field.name & "Setter")
        fieldName = field.name
        configVar = ident "config"
        configField = newTree(nnkDotExpr, configVar, fieldName)
        defaultValue = field.readPragma"defaultValue"

      if defaultValue == nil:
        defaultValue = newCall(makeDefaultValue, newTree(nnkTypeOfExpr, configField))

      # TODO: This shouldn't be necessary. The type symbol returned from Nim should
      # be typed as a tyTypeDesc[tyString] instead of just `tyString`. To be filed.
      var fixedFieldType = newTree(nnkTypeOfExpr, field.typ)

      settersArray.add newTree(nnkTupleConstr,
                               newLit($fieldName),
                               newCall(bindSym"FieldSetter", setterName),
                               newCall(bindSym"requiresInput", fixedFieldType))

      result.add quote do:
        proc `setterName`(`configVar`: var `RecordType`, val: TaintedString): bool {.nimcall.} =
          when `configField` is enum:
            # TODO: For some reason, the normal `setField` rejects enum fields
            # when they are used as case discriminators. File this as a bug.
            if len(val) > 0:
              `configField` = parseEnum[type(`configField`)](string(val))
            else:
              `configField` = `defaultValue`
            return true
          else:
            return setField(`configField`, val, `defaultValue`)

    result.add settersArray
    debugMacroResult "Field Setters"

  macro buildCommandTree(RecordType: type): untyped =
    var recordDef = RecordType.getType[1].getImpl
    var fieldIdx = 0
    # TODO Handle arbitrary sub-command trees more properly
    # var cmdStack = newSeq[(NimNode, CommandDesc)]()
    var res = CommandDesc()
    res.argumentsFieldIdx = -1
    res.defaultSubCommand = -1

    for field in recordFields(recordDef):
      let
        isCommand = field.readPragma"command" != nil
        isDiscriminator = field.caseField != nil and field.caseBranch == nil
        defaultValue = field.readPragma"defaultValue"
        shortform = field.readPragma"shortform"
        longform = field.readPragma"longform"
        desc = field.readPragma"desc"

      if isDiscriminator:
        # TODO Handle
        let cmdType = field.typ.getImpl[^1]
        if cmdType.kind != nnkEnumTy:
          error "Only enums are supported as case object discriminators", field.name
        for i in 1 ..< cmdType.len:
          let name = $cmdType[i]
          if defaultValue != nil and $name == $defaultValue:
            res.defaultSubCommand = res.subCommands.len
          res.subCommands.add CommandDesc(name: name,
                                          fieldIdx: fieldIdx,
                                          argumentsFieldIdx: -1,
                                          defaultSubCommand: -1)
      elif isCommand:
        # TODO Handle string commands
        # (But perhaps these are no different than arguments)
        discard
      else:
        var option = OptionDesc()
        option.fieldIdx = fieldIdx
        option.name = $field.name
        option.hasDefault = defaultValue != nil
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
  printCmdTree rootCmd

  let confAddr = addr result
  var activeCmds = @[rootCmd]
  template lastCmd: auto = activeCmds[^1]
  var rejectNextArgument = lastCmd.argumentsFieldIdx == -1

  proc fail(msg: string) =
    if quitOnFailure:
      stderr.writeLine(msg)
      stderr.writeLine("Try '$1 --help' for more information" % appInvocation())
      quit 1
    else:
      raise newException(ConfigurationError, msg)

  template applySetter(setterIdx: int, cmdLineVal: TaintedString): bool =
    var r: bool
    try:
      r = fieldSetters[setterIdx][1](confAddr[], cmdLineVal)
    except:
      fail("Invalid value for " & fieldSetters[setterIdx][0] & ": " &
           getCurrentExceptionMsg())
    r

  template required(opt: OptionDesc): bool =
    fieldSetters[opt.fieldIdx][2] and not opt.hasDefault

  proc processMissingOptions(conf: var Configuration, cmd: CommandPtr) =
    for o in cmd.options:
      if o.rejectNext == false:
        if o.required:
          fail "The required option '$1' was not specified" % [o.name]
        elif o.hasDefault:
          discard fieldSetters[o.fieldIdx][1](conf, TaintedString(""))

  template activateCmd(activatedCmd: CommandPtr, key: TaintedString) =
    let cmd = activatedCmd
    discard applySetter(cmd.fieldIdx, key)
    lastCmd.defaultSubCommand = -1
    activeCmds.add cmd
    rejectNextArgument = not cmd.hasArguments

  for kind, key, val in getopt(cmdLine):
    case kind
    of cmdLongOption, cmdShortOption:
      if string(key) == "help":
        showHelp version, lastCmd

      var option = findOption(activeCmds, key)
      if option == nil:
        # We didn't find the option.
        # Check if it's from the default command and activate it if necessary:
        if lastCmd.defaultSubCommand != -1:
          let defaultSubCmd = lastCmd.subCommands[lastCmd.defaultSubCommand]
          option = findOption(@[defaultSubCmd], key)
          if option != nil:
            activateCmd(defaultSubCmd, TaintedString(""))

      if option != nil:
        if option.rejectNext:
          fail "The options '$1' should not be specified more than once" % [string(key)]
        option.rejectNext = applySetter(option.fieldIdx, val)
      else:
        fail "Unrecognized option '$1'" % [string(key)]

    of cmdArgument:
      if string(key) == "help" and lastCmd.subCommands.len > 0:
        showHelp version, lastCmd

      let subCmd = lastCmd.findSubcommand(key)
      if subCmd != nil:
        activateCmd(subCmd, key)
      else:
        if rejectNextArgument:
          fail lastCmd.noMoreArgumentsError

        let argumentIdx = lastCmd.argumentsFieldIdx
        doAssert argumentIdx != -1
        rejectNextArgument = applySetter(argumentIdx, key)

    else:
      discard

  for cmd in activeCmds:
    result.processMissingOptions(cmd)
    if cmd.defaultSubCommand != -1:
      result.processMissingOptions(cmd.subCommands[cmd.defaultSubCommand])

proc defaults*(Configuration: type): Configuration =
  load(Configuration, cmdLine = @[], printUsage = false, quitOnFailure = false)

proc dispatchImpl(cliProcSym, cliArgs, loadArgs: NimNode): NimNode =
  # Here, we'll create a configuration object with fields matching
  # the CLI proc params. We'll also generate a call to the designated proc
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

proc load*(f: TypedInputFile): f.ContentType =
  when f.Format is Unspecified or f.ContentType is Unspecified:
    {.fatal: "To use `InputFile.load`, please specify the Format and ContentType of the file".}

  when f.Format is Txt:
    # TODO: implement a proper Txt serialization format
    mixin init
    f.ContentType.init readFile(f.string).string
  else:
    mixin loadFile
    loadFile(f.Format, f.string, f.ContentType)

