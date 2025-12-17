# confutils
# Copyright (c) 2018-2024 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

{.push raises: [].}

import
  os,
  std/[enumutils, options, strutils, wordwrap],
  stew/shims/macros,
  confutils/[defs, cli_parser, config_file]

export
  options, defs, config_file

const
  hasSerialization = not defined(nimscript)
  useBufferedOutput = defined(nimscript)
  noColors = useBufferedOutput or defined(confutils_no_colors)
  hasCompletions = not defined(nimscript)
  descPadding = 6
  minNameWidth =  24 - descPadding

when hasSerialization:
  import serialization
  export serialization

when not defined(nimscript):
  import
    terminal,
    confutils/shell_completion

type
  HelpFlag = enum
    hlpDebug

  HelpAppInfo = ref object
    appInvocation: string
    copyrightBanner: string
    hasAbbrs: bool
    hasVersion: bool
    hasDebugOpts: bool
    maxNameLen: int
    terminalWidth: int
    namesWidth: int
    flags: set[HelpFlag]

  CmdInfo = ref object
    name: string
    desc: string
    opts: seq[OptInfo]

  OptKind = enum
    Discriminator
    CliSwitch
    Arg

  OptFlag = enum
    optHidden
    optDebug

  OptInfo = ref object
    name, abbr, desc, typename: string
    separator: string
    longDesc: string
    idx: int
    flags: set[OptFlag]
    hasDefault: bool
    defaultInHelpText: string
    case kind: OptKind
    of Discriminator:
      isCommand: bool
      isImplicitlySelectable: bool
      subCmds: seq[CmdInfo]
      defaultSubCmd: int
    else:
      discard

const
  confutils_description_width {.intdefine.} = 80
  confutils_narrow_terminal_width {.intdefine.} = 36

{.push gcsafe, raises: [].}

func toHelpFlags(s: string): set[HelpFlag] =
  # if adding more flags parse `debug:experimental:etc`
  case s
  of "debug":
    result.incl hlpDebug
  else:
    discard

func getFieldName(caseField: NimNode): NimNode =
  result = caseField
  if result.kind == nnkIdentDefs: result = result[0]
  if result.kind == nnkPragmaExpr: result = result[0]
  if result.kind == nnkPostfix: result = result[1]

when defined(nimscript):
  func scriptNameParamIdx: int =
    for i in 1 ..< paramCount():
      var param = paramStr(i)
      if param.len > 0 and param[0] != '-':
        return i

  proc appInvocation: string =
    let scriptNameIdx = scriptNameParamIdx()
    "nim " & (if paramCount() > scriptNameIdx: paramStr(scriptNameIdx) else: "<nims-script>")

  type stderr = object

  template writeLine(T: type stderr, msg: string) =
    echo msg

  proc commandLineParams(): seq[string] =
    for i in scriptNameParamIdx() + 1 .. paramCount():
      result.add paramStr(i)

  # TODO: Why isn't this available in NimScript?
  proc getCurrentExceptionMsg(): string =
    ""

  template terminalWidth: int =
    100000

else:
  template appInvocation: string =
    try:
      getAppFilename().splitFile.name
    except OSError:
      ""

when noColors:
  const
    styleBright = ""
    fgYellow = ""
    fgWhite = ""
    fgGreen = ""
    fgCyan = ""
    fgBlue = ""
    resetStyle = ""

when useBufferedOutput:
  template helpOutput(args: varargs[string]) =
    for arg in args:
      help.add arg

  template errorOutput(args: varargs[string]) =
    helpOutput(args)

  template flushOutput =
    echo help

else:
  template errorOutput(args: varargs[untyped]) =
    try:
      styledWrite stderr, args
    except IOError, ValueError:
      discard

  template helpOutput(args: varargs[untyped]) =
    try:
      styledWrite stdout, args
    except IOError, ValueError:
      discard

  template flushOutput =
    discard

const
  fgSection = fgYellow
  fgDefault = fgWhite
  fgCommand = fgCyan
  fgOption = fgBlue
  fgArg = fgBlue

  # TODO: Start using these:
  # fgValue = fgGreen
  # fgType = fgYellow

template flushOutputAndQuit(exitCode: int) =
  flushOutput
  quit exitCode

func helpOptDesc(appInfo: HelpAppInfo): string =
  result = "Show this help message and exit"
  if appInfo.hasDebugOpts:
    result.add ". Available arguments: debug"

func isCliSwitch(opt: OptInfo): bool =
  opt.kind == CliSwitch or
  (opt.kind == Discriminator and opt.isCommand == false)

func isOpt(opt: OptInfo, excl: set[OptFlag]): bool =
  opt.isCliSwitch and excl * opt.flags == {}

func hasOpts(cmd: CmdInfo, excl: set[OptFlag]): bool =
  for opt in cmd.opts:
    if opt.isOpt(excl):
      return true
  false

func hasArgs(cmd: CmdInfo): bool =
  for opt in cmd.opts:
    if opt.kind == Arg:
      return true
  false

iterator args(cmd: CmdInfo): OptInfo =
  for opt in cmd.opts:
    if opt.kind == Arg:
      yield opt

func getSubCmdDiscriminator(cmd: CmdInfo): OptInfo =
  for i in countdown(cmd.opts.len - 1, 0):
    let opt = cmd.opts[i]
    if opt.kind != Arg:
      if opt.kind == Discriminator and opt.isCommand:
        return opt
      else:
        return nil

template hasSubCommands(cmd: CmdInfo): bool =
  getSubCmdDiscriminator(cmd) != nil

iterator subCmds(cmd: CmdInfo): CmdInfo =
  let subCmdDiscriminator = cmd.getSubCmdDiscriminator
  if subCmdDiscriminator != nil:
    for cmd in subCmdDiscriminator.subCmds:
      yield cmd

template isSubCommand(cmd: CmdInfo): bool =
  cmd.name.len > 0

iterator helpOptsIt(cmd: CmdInfo, inclCmds: bool, excl: set[OptFlag]): OptInfo =
  var q = @[cmd]
  while q.len > 0:
    let c = q.pop()
    for opt in c.opts:
      if opt.isOpt(excl) or opt.kind == Arg:
        if opt.kind == Discriminator:
          for subCmd in opt.subCmds:
            q.add subCmd
        yield opt
      elif inclCmds and opt.kind == Discriminator and opt.isCommand:
        for subCmd in opt.subCmds:
          q.add subCmd

iterator helpOptsIt(cmds: openArray[CmdInfo], excl: set[OptFlag]): OptInfo =
  for i, cmd in cmds:
    let inclCmds = i == cmds.high
    for opt in helpOptsIt(cmd, inclCmds, excl):
      yield opt

func maxNameLen(cmds: openArray[CmdInfo], excl: set[OptFlag]): int =
  result = 0
  for opt in helpOptsIt(cmds, excl):
    result = max(result, opt.name.len)

func hasAbbrs(cmds: openArray[CmdInfo], excl: set[OptFlag]): bool =
  for opt in helpOptsIt(cmds, excl):
    if opt.abbr.len > 0:
      return true
  false

func hasDebugOpts(cmds: openArray[CmdInfo]): bool =
  let excl = {optHidden}
  for opt in helpOptsIt(cmds, excl):
    if optDebug in opt.flags:
      return true
  false

func humaneName(opt: OptInfo): string =
  if opt.name.len > 0: opt.name
  else: opt.abbr

template padding(output: string, desiredWidth: int): string =
  spaces(max(desiredWidth - output.len, 0))

proc writeDesc(help: var string,
               appInfo: HelpAppInfo,
               desc, defaultValue: string) =
  const descSpacing = "  "
  let
    descIndent = (5 + appInfo.namesWidth + descSpacing.len)
    remainingColumns = appInfo.terminalWidth - descIndent
    defaultValSuffix = if defaultValue.len == 0: ""
                       else: " [=" & defaultValue & "]"
    fullDesc = desc & defaultValSuffix & "."

  if remainingColumns < confutils_narrow_terminal_width:
    helpOutput "\p ", wrapWords(fullDesc, appInfo.terminalWidth - 2,
                                newLine = "\p ")
  else:
    let wrappingWidth = min(remainingColumns, confutils_description_width)
    helpOutput descSpacing, wrapWords(fullDesc, wrappingWidth,
                                      newLine = "\p" & spaces(descIndent))

proc writeLongDesc(help: var string,
               appInfo: HelpAppInfo,
               desc: string) =
  let lines = split(desc, {'\n', '\r'})
  for line in lines:
    if line.len > 0:
      helpOutput "\p"
      helpOutput padding("", 5 + appInfo.namesWidth)
      help.writeDesc appInfo, line, ""

proc describeInvocation(
  help: var string,
  cmd: CmdInfo,
  cmdInvocation: string,
  appInfo: HelpAppInfo,
  excl: set[OptFlag],
  showBuiltIns = false
) =
  helpOutput styleBright, "\p", fgCommand, cmdInvocation

  if cmd.hasOpts(excl) or showBuiltIns:
    helpOutput " [OPTIONS]..."

  let subCmdDiscriminator = cmd.getSubCmdDiscriminator
  if subCmdDiscriminator != nil:
    helpOutput " command"

  for arg in cmd.args:
    helpOutput " <", arg.name, ">"

  helpOutput "\p"

  if cmd.desc.len > 0:
    helpOutput "\p", cmd.desc, ".\p"

  var argsSectionStarted = false

  for arg in cmd.args:
    if arg.desc.len > 0:
      if not argsSectionStarted:
        helpOutput "\p"
        argsSectionStarted = true
      helpOutput " "
      if appInfo.hasAbbrs:
        helpOutput "    "
      let cliArg = "<" & arg.name & ">"
      helpOutput fgArg, styleBright, cliArg
      helpOutput padding(cliArg, appInfo.namesWidth)
      help.writeDesc appInfo, arg.desc, arg.defaultInHelpText
      help.writeLongDesc appInfo, arg.longDesc
      helpOutput "\p"

type
  OptionsType = enum
    normalOpts
    defaultCmdOpts
    conditionalOpts

proc describeOptionsList(
  help: var string,
  opts: openArray[OptInfo],
  appInfo: HelpAppInfo,
  excl: set[OptFlag]
) =
  for opt in opts:
    if not opt.isOpt(excl):
      continue

    if opt.separator.len > 0:
      helpOutput opt.separator
      helpOutput "\p"

    # Indent all command-line switches
    helpOutput " "

    if opt.abbr.len > 0:
      helpOutput fgOption, styleBright, "-", opt.abbr, ", "
    elif appInfo.hasAbbrs:
      # Add additional indentatition, so all names are aligned
      helpOutput "    "

    if opt.name.len > 0:
      let switch = "--" & opt.name
      helpOutput fgOption, styleBright,
                  switch, padding(switch, appInfo.namesWidth)
    else:
      helpOutput spaces(2 + appInfo.namesWidth)

    if opt.desc.len > 0:
      help.writeDesc appInfo,
                      opt.desc.replace("%t", opt.typename),
                      opt.defaultInHelpText
      help.writeLongDesc appInfo, opt.longDesc

    helpOutput "\p"

proc describeOptions(
  help: var string,
  cmds: openArray[CmdInfo],
  cmdInvocation: string,
  appInfo: HelpAppInfo,
  excl: set[OptFlag],
  optionsType = normalOpts,
  showBuiltIns = false
) =
  if cmds.len == 0:
    return

  var hasOpts = false
  for c in cmds:
    if c.hasOpts(excl):
      hasOpts = true

  if hasOpts or showBuiltIns:
    case optionsType
    of normalOpts:
      helpOutput "\pThe following options are available:\p\p"
    of conditionalOpts:
      helpOutput ", the following additional options are available:\p\p"
    of defaultCmdOpts:
      discard

    if showBuiltIns:
      let helpOpt = OptInfo(
        kind: CliSwitch,
        name: "help",
        desc: helpOptDesc(appInfo)
      )
      describeOptionsList(help, [helpOpt], appInfo, excl)
      if appInfo.hasVersion:
        let versionOpt = OptInfo(
          kind: CliSwitch,
          name: "version",
          desc: "Show program's version and exit"
        )
        describeOptionsList(help, [versionOpt], appInfo, excl)

    for c in cmds:
      describeOptionsList(help, c.opts, appInfo, excl)

    for c in cmds:
      for opt in c.opts:
        if opt.isOpt(excl) and opt.kind == Discriminator:
          for i, subCmd in opt.subCmds:
            if not subCmd.hasOpts(excl):
              continue

            helpOutput "\pWhen ", styleBright, fgBlue, opt.humaneName, resetStyle, " = ", fgGreen, subCmd.name

            if i == opt.defaultSubCmd:
              helpOutput " (default)"
            help.describeOptions [subCmd], cmdInvocation, appInfo, excl, conditionalOpts

  let cmd = cmds[^1]
  let subCmdDiscriminator = cmd.getSubCmdDiscriminator
  if subCmdDiscriminator != nil:
    let defaultCmdIdx = subCmdDiscriminator.defaultSubCmd
    if defaultCmdIdx != -1:
      let defaultCmd = subCmdDiscriminator.subCmds[defaultCmdIdx]
      help.describeOptions [defaultCmd], cmdInvocation, appInfo, excl, defaultCmdOpts

    helpOutput fgSection, "\pAvailable sub-commands:\p"

    for i, subCmd in subCmdDiscriminator.subCmds:
      if i != subCmdDiscriminator.defaultSubCmd:
        let subCmdInvocation = cmdInvocation & " " & subCmd.name
        help.describeInvocation subCmd, subCmdInvocation, appInfo, excl
        help.describeOptions [subCmd], subCmdInvocation, appInfo, excl

proc showHelp(help: var string,
              appInfo: HelpAppInfo,
              activeCmds: openArray[CmdInfo]) =
  if appInfo.copyrightBanner.len > 0:
    helpOutput appInfo.copyrightBanner, "\p\p"

  let cmd = activeCmds[^1]

  var excl = {optHidden}
  if hlpDebug notin appInfo.flags:
    excl.incl optDebug

  appInfo.maxNameLen = maxNameLen(activeCmds, excl)
  appInfo.hasAbbrs = hasAbbrs(activeCmds, excl)
  appInfo.hasDebugOpts = hasDebugOpts(activeCmds)
  let termWidth =
    try:
      terminalWidth()
    except ValueError:
      int.high  # https://github.com/nim-lang/Nim/pull/21968
  if appInfo.terminalWidth == 0:
    appInfo.terminalWidth = termWidth
  appInfo.namesWidth = min(minNameWidth, appInfo.maxNameLen) + descPadding

  var cmdInvocation = appInfo.appInvocation
  for i in 1 ..< activeCmds.len:
    cmdInvocation.add " "
    cmdInvocation.add activeCmds[i].name

  # Write out the app or script name
  helpOutput fgSection, "Usage: \p"
  help.describeInvocation cmd, cmdInvocation, appInfo, excl, showBuiltIns = true
  help.describeOptions activeCmds, cmdInvocation, appInfo, excl, showBuiltIns = true
  helpOutput "\p"

  flushOutputAndQuit QuitSuccess

func getNextArgIdx(cmd: CmdInfo, consumedArgIdx: int): int =
  for i in 0 ..< cmd.opts.len:
    if cmd.opts[i].kind == Arg and cmd.opts[i].idx > consumedArgIdx:
      return cmd.opts[i].idx

  -1

proc noMoreArgsError(cmd: CmdInfo): string {.raises: [].} =
  result =
    if cmd.isSubCommand:
      "The command '" & cmd.name & "'"
    else:
      appInvocation()
  result.add " does not accept"
  if cmd.hasArgs: result.add " additional"
  result.add " arguments"

func findOpt(opts: openArray[OptInfo], name: string): OptInfo =
  for opt in opts:
    if cmpIgnoreStyle(opt.name, name) == 0 or
       cmpIgnoreStyle(opt.abbr, name) == 0:
      return opt

func findOpt(activeCmds: openArray[CmdInfo], name: string): OptInfo =
  for i in countdown(activeCmds.len - 1, 0):
    let found = findOpt(activeCmds[i].opts, name)
    if found != nil: return found

func findCmd(cmds: openArray[CmdInfo], name: string): CmdInfo =
  for cmd in cmds:
    if cmpIgnoreStyle(cmd.name, name) == 0:
      return cmd

func findSubCmd(cmd: CmdInfo, name: string): CmdInfo =
  let subCmdDiscriminator = cmd.getSubCmdDiscriminator
  if subCmdDiscriminator != nil:
    let cmd = findCmd(subCmdDiscriminator.subCmds, name)
    if cmd != nil: return cmd

  return nil

func startsWithIgnoreStyle(s: string, prefix: string): bool =
  # Similar in spirit to cmpIgnoreStyle, but compare only the prefix.
  var i = 0
  var j = 0

  while true:
    # Skip any underscore
    while i < s.len and s[i] == '_': inc i
    while j < prefix.len and prefix[j] == '_': inc j

    if j == prefix.len:
      # The whole prefix matches
      return true
    elif i == s.len:
      # We've reached the end of `s` without matching the prefix
      return false
    elif toLowerAscii(s[i]) != toLowerAscii(prefix[j]):
      return false

    inc i
    inc j

when defined(debugCmdTree):
  proc printCmdTree(cmd: CmdInfo, indent = 0) =
    let blanks = spaces(indent)
    echo blanks, "> ", cmd.name

    for opt in cmd.opts:
      if opt.kind == Discriminator:
        for subcmd in opt.subCmds:
          printCmdTree(subcmd, indent + 2)
      else:
        echo blanks, "  - ", opt.name, ": ", opt.typename

else:
  template printCmdTree(cmd: CmdInfo) = discard

# TODO remove the overloads here to get better "missing overload" error message
proc parseCmdArg*(T: type InputDir, p: string): T {.raises: [ValueError].} =
  if not dirExists(p):
    raise newException(ValueError, "Directory doesn't exist")

  T(p)

proc parseCmdArg*(T: type InputFile, p: string): T {.raises: [ValueError].} =
  # TODO this is needed only because InputFile cannot be made
  # an alias of TypedInputFile at the moment, because of a generics
  # caching issue
  if not fileExists(p):
    raise newException(ValueError, "File doesn't exist")

  when not defined(nimscript):
    try:
      let f = system.open(p, fmRead)
      close f
    except IOError:
      raise newException(ValueError, "File not accessible")

  T(p)

proc parseCmdArg*(
    T: type TypedInputFile, p: string): T {.raises: [ValueError].} =
  var path = p
  when T.defaultExt.len > 0:
    path = path.addFileExt(T.defaultExt)

  if not fileExists(path):
    raise newException(ValueError, "File doesn't exist")

  when not defined(nimscript):
    try:
      let f = system.open(path, fmRead)
      close f
    except IOError:
      raise newException(ValueError, "File not accessible")

  T(path)

func parseCmdArg*(T: type[OutDir|OutFile|OutPath], p: string): T =
  T(p)

proc parseCmdArg*[T](
    _: type Option[T], s: string): Option[T] {.raises: [ValueError].} =
  some(parseCmdArg(T, s))

template parseCmdArg*(T: type string, s: string): string =
  s

func parseCmdArg*(
    T: type SomeSignedInt, s: string): T {.raises: [ValueError].} =
  let res = parseBiggestInt(s)
  if res > T.high:
    raise newException(ValueError, s & " exceeds max value of " & $T.high)
  if res < T.low:
    raise newException(ValueError, s & " exceeds min value of " & $T.low)
  T(res)

func parseCmdArg*(
    T: type SomeUnsignedInt, s: string): T {.raises: [ValueError].} =
  let res = parseBiggestUInt(s)
  if res > T.high:
    raise newException(ValueError, s & " exceeds max value of " & $T.high)
  T(res)

func parseCmdArg*(T: type SomeFloat, p: string): T {.raises: [ValueError].} =
  parseFloat(p)

func parseCmdArg*(T: type bool, p: string): T {.raises: [ValueError].} =
  try:
    p.len == 0 or parseBool(p)
  except CatchableError:
    raise newException(ValueError, "'" & p & "' is not a valid boolean value. Supported values are on/off, yes/no, true/false or 1/0")

func parseEnumNormalized[T: enum](s: string): T {.raises: [ValueError].} =
  # Note: In Nim 1.6 `parseEnum` normalizes the string except for the first
  # character. Nim 1.2 would normalize for all characters. In config options
  # the latter behaviour is required so this custom function is needed.
  genEnumCaseStmt(T, s, default = nil, ord(low(T)), ord(high(T)), normalize)

func parseCmdArg*(T: type enum, s: string): T {.raises: [ValueError].} =
  parseEnumNormalized[T](s)

proc parseCmdArgAux(T: type, s: string): T {.raises: [ValueError].} =
  # The parseCmdArg procs are allowed to raise only `ValueError`.
  # If you have provided your own specializations, please handle
  # all other exception types.
  mixin parseCmdArg
  try:
    parseCmdArg(T, s)
  except CatchableError as exc:
    raise newException(ValueError, exc.msg)

func completeCmdArg*(T: type enum, val: string): seq[string] =
  for e in low(T)..high(T):
    let as_str = $e
    if startsWithIgnoreStyle(as_str, val):
      result.add($e)

func completeCmdArg*(T: type SomeNumber, val: string): seq[string] =
  @[]

func completeCmdArg*(T: type bool, val: string): seq[string] =
  @[]

func completeCmdArg*(T: type string, val: string): seq[string] =
  @[]

proc completeCmdArg*(T: type[InputFile|TypedInputFile|InputDir|OutFile|OutDir|OutPath],
                     val: string): seq[string] =
  when not defined(nimscript):
    let (dir, name, ext) = splitFile(val)
    let tail = name & ext
    # Expand the directory component for the directory walker routine
    let dir_path = if dir == "": "." else: expandTilde(dir)
    # Dotfiles are hidden unless the user entered a dot as prefix
    let show_dotfiles = len(name) > 0 and name[0] == '.'

    try:
      for kind, path in walkDir(dir_path, relative=true):
        if not show_dotfiles and path[0] == '.':
          continue

        # Do not show files if asked for directories, on the other hand we must show
        # directories even if a file is requested to allow the user to select a file
        # inside those
        if type(T) is (InputDir or OutDir) and kind notin {pcDir, pcLinkToDir}:
          continue

        # Note, no normalization is needed here
        if path.startsWith(tail):
          var match = dir_path / path
          # Add a trailing slash so that completions can be chained
          if kind in {pcDir, pcLinkToDir}:
            match &= DirSep

          result.add(shellPathEscape(match))
    except OSError:
      discard

func completeCmdArg*[T](_: type seq[T], val: string): seq[string] =
  @[]

proc completeCmdArg*[T](_: type Option[T], val: string): seq[string] =
  mixin completeCmdArg
  return completeCmdArg(type(T), val)

proc completeCmdArgAux(T: type, val: string): seq[string] =
  mixin completeCmdArg
  return completeCmdArg(T, val)

template setField[T](
    loc: var T, val: Option[string], defaultVal: untyped): untyped =
  type FieldType = type(loc)
  loc = if isSome(val): parseCmdArgAux(FieldType, val.get)
        else: FieldType(defaultVal)

template setField[T](
    loc: var seq[T], val: Option[string], defaultVal: untyped): untyped =
  if val.isSome:
    loc.add parseCmdArgAux(type(loc[0]), val.get)
  else:
    type FieldType = type(loc)
    loc = FieldType(defaultVal)

func makeDefaultValue*(T: type): T =
  default(T)

func requiresInput*(T: type): bool =
  not ((T is seq) or (T is Option) or (T is bool))

func acceptsMultipleValues*(T: type): bool =
  T is seq

template debugMacroResult(macroName: string) {.dirty.} =
  when defined(debugMacros) or defined(debugConfutils):
    echo "\n-------- ", macroName, " ----------------------"
    echo result.repr

proc generateFieldSetters(RecordType: NimNode): NimNode =
  var recordDef = getImpl(RecordType)
  let makeDefaultValue = bindSym"makeDefaultValue"

  result = newTree(nnkStmtListExpr)
  var settersArray = newTree(nnkBracket)

  for field in recordFields(recordDef):
    var
      setterName = ident($field.name & "Setter")
      fieldName = field.name
      namePragma = field.readPragma"name"
      paramName = if namePragma != nil: namePragma
                  else: fieldName
      configVar = ident "config"
      configField = newTree(nnkDotExpr, configVar, fieldName)
      defaultValue = field.readPragma"defaultValue"
      completerName = ident($field.name & "Complete")
      isFieldDiscriminator = newLit field.isDiscriminator

    if defaultValue == nil:
      defaultValue = newCall(makeDefaultValue, newTree(nnkTypeOfExpr, configField))

    # TODO: This shouldn't be necessary. The type symbol returned from Nim should
    # be typed as a tyTypeDesc[tyString] instead of just `tyString`. To be filed.
    var fixedFieldType = newTree(nnkTypeOfExpr, field.typ)

    settersArray.add newTree(nnkTupleConstr,
                             newLit($paramName),
                             setterName, completerName,
                             newCall(bindSym"requiresInput", fixedFieldType),
                             newCall(bindSym"acceptsMultipleValues", fixedFieldType))

    result.add quote do:
      {.push hint[XCannotRaiseY]: off.}

    result.add quote do:
      proc `completerName`(val: string): seq[string] {.
        nimcall
        gcsafe
        sideEffect
        raises: []
      .} =
        return completeCmdArgAux(`fixedFieldType`, val)

      proc `setterName`(`configVar`: var `RecordType`, val: Option[string]) {.
        nimcall
        gcsafe
        sideEffect
        raises: [ValueError]
      .} =
        # This works as long as the object is fresh (i.e: `default(theObj)`)
        # and the fields are processed in order.
        # See https://github.com/status-im/nim-confutils/pull/117
        # for a general solution.
        when `isFieldDiscriminator`:
          {.cast(uncheckedAssign).}:
            setField(`configField`, val, `defaultValue`)
        else:
          setField(`configField`, val, `defaultValue`)

    result.add quote do:
      {.pop.}

  result.add settersArray
  debugMacroResult "Field Setters"

func checkDuplicate(cmd: CmdInfo, opt: OptInfo, fieldName: NimNode) =
  for x in cmd.opts:
    if opt.name == x.name:
      error "duplicate name detected: " & opt.name, fieldName
    if opt.abbr.len > 0 and opt.abbr == x.abbr:
      error "duplicate abbr detected: " & opt.abbr, fieldName

func validPath(path: var seq[CmdInfo], parent, node: CmdInfo): bool =
  for x in parent.opts:
    if x.kind != Discriminator: continue
    for y in x.subCmds:
      if y == node:
        path.add y
        return true
      if validPath(path, y, node):
        path.add y
        return true
  false

func findPath(parent, node: CmdInfo): seq[CmdInfo] =
  # find valid path from parent to node
  result = newSeq[CmdInfo]()
  doAssert validPath(result, parent, node)
  result.add parent

func toText(n: NimNode): string =
  if n == nil: ""
  elif n.kind in {nnkStrLit..nnkTripleStrLit}: n.strVal
  else: repr(n)

func readPragmaFlags(field: FieldDescription): set[OptFlag] =
  result = {}
  if field.readPragma("hidden") != nil:
    result.incl optHidden
  if field.readPragma("debug") != nil:
    result.incl optDebug

proc cmdInfoFromType(T: NimNode): CmdInfo =
  result = CmdInfo()

  var
    recordDef = getImpl(T)
    discriminatorFields = newSeq[OptInfo]()
    fieldIdx = 0

  for field in recordFields(recordDef):
    let
      isImplicitlySelectable = field.readPragma"implicitlySelectable" != nil
      defaultValue = field.readPragma"defaultValue"
      defaultValueDesc = field.readPragma"defaultValueDesc"
      defaultInHelp = if defaultValueDesc != nil: defaultValueDesc
                      else: defaultValue
      defaultInHelpText = toText(defaultInHelp)
      separator = field.readPragma"separator"
      longDesc = field.readPragma"longDesc"
      abbr = field.readPragma"abbr"
      name = field.readPragma"name"
      desc = field.readPragma"desc"
      optKind = if field.isDiscriminator: Discriminator
                elif field.readPragma("argument") != nil: Arg
                else: CliSwitch
      optFlags = field.readPragmaFlags()

    var opt = OptInfo(kind: optKind,
                      idx: fieldIdx,
                      name: $field.name,
                      flags: optFlags,
                      hasDefault: defaultValue != nil,
                      defaultInHelpText: defaultInHelpText,
                      typename: field.typ.repr)

    if desc != nil: opt.desc = desc.strVal
    if name != nil: opt.name = name.strVal
    if abbr != nil: opt.abbr = abbr.strVal
    if separator != nil: opt.separator = separator.strVal
    if longDesc != nil: opt.longDesc = longDesc.strVal

    inc fieldIdx

    if field.isDiscriminator:
      discriminatorFields.add opt
      let cmdType = field.typ.getImpl[^1]
      if cmdType.kind != nnkEnumTy:
        error "Only enums are supported as case object discriminators", field.name

      opt.isImplicitlySelectable = isImplicitlySelectable
      opt.isCommand = field.readPragma"command" != nil

      for i in 1 ..< cmdType.len:
        let enumVal = cmdType[i]
        var name, desc: string
        if enumVal.kind == nnkEnumFieldDef:
          name = $enumVal[0]
          desc = $enumVal[1]
        else:
          name = $enumVal
        if defaultValue != nil and eqIdent(name, defaultValue):
          opt.defaultSubCmd = i - 1
        opt.subCmds.add CmdInfo(name: name, desc: desc)

      if defaultValue == nil:
        opt.defaultSubCmd = -1
      else:
        if opt.defaultSubCmd == -1:
          error "The default value is not a valid enum value", defaultValue

    if field.caseField != nil and field.caseBranch != nil:
      let fieldName = field.caseField.getFieldName
      var discriminator = findOpt(discriminatorFields, $fieldName)

      if discriminator == nil:
        error "Unable to find " & $fieldName

      if field.caseBranch.kind == nnkElse:
        error "Sub-command parameters cannot appear in an else branch. " &
              "Please specify the sub-command branch precisely", field.caseBranch[0]

      var branchEnumVal = field.caseBranch[0]
      if branchEnumVal.kind == nnkDotExpr:
        branchEnumVal = branchEnumVal[1]
      var cmd = findCmd(discriminator.subCmds, $branchEnumVal)
      # we respect subcommand hierarchy when looking for duplicate
      let path = findPath(result, cmd)
      for n in path:
        checkDuplicate(n, opt, field.name)

      # the reason we check for `ignore` pragma here and not using `continue` statement
      # is we do respect option hierarchy of subcommands
      if field.readPragma("ignore") == nil:
        cmd.opts.add opt

    else:
      checkDuplicate(result, opt, field.name)

      if field.readPragma("ignore") == nil:
        result.opts.add opt

macro configurationRtti(RecordType: type): untyped =
  let
    T = RecordType.getType[1]
    cmdInfo = cmdInfoFromType T
    fieldSetters = generateFieldSetters T

  result = newTree(nnkPar, newLitFixed cmdInfo, fieldSetters)

when hasSerialization:
  template addConfigFileImpl(
      secondarySources: auto,
      Format: type SerializationFormat,
      path: InputFile,
      params: varargs[untyped]
  ): untyped =
    try:
      secondarySources.data.add loadFile(
        Format, string path, typeof(secondarySources.data[0]), params
      )
    except SerializationError as err:
      raise newException(ConfigurationError, err.formatMsg(string path), err)
    except IOError as err:
      raise newException(ConfigurationError,
        "Failed to read config file at '" & string(path) & "': " & err.msg)

  template addConfigFileWithParams*(
      secondarySources: auto,
      Format: type SerializationFormat,
      path: InputFile,
      params: varargs[untyped]
  ): untyped =
    addConfigFileImpl(secondarySources, Format, path, params)

  proc addConfigFile*(
      secondarySources: auto,
      Format: type SerializationFormat,
      path: InputFile
  ) {.raises: [ConfigurationError].} =
    addConfigFileImpl(secondarySources, Format, path)

  template addConfigFileContentImpl(
      secondarySources: auto,
      Format: type SerializationFormat,
      content: string,
      params: varargs[untyped]
  ): untyped =
    try:
      secondarySources.data.add decode(
        Format, content, type(secondarySources.data[0], params)
      )
    except SerializationError as err:
      raise newException(ConfigurationError, err.formatMsg("<content>"), err)
    except IOError:
      raiseAssert "This should not be possible"

  template addConfigFileContentWithParams*(
      secondarySources: auto,
      Format: type SerializationFormat,
      content: string,
      params: varargs[untyped]
  ): untyped =
    addConfigFileContentImpl(secondarySources, Format, content, params)

  proc addConfigFileContent*(
      secondarySources: auto,
      Format: type SerializationFormat,
      content: string
  ) {.raises: [ConfigurationError].} =
    addConfigFileContentImpl(secondarySources, Format, content)

func constructEnvKey*(prefix: string, key: string): string {.raises: [].} =
  ## Generates env. variable names from keys and prefix following the
  ## IEEE Open Group env. variable spec: https://pubs.opengroup.org/onlinepubs/000095399/basedefs/xbd_chap08.html
  (prefix & "_" & key).toUpperAscii.multiReplace(("-", "_"), (" ", "_"))

# On Posix there is no portable way to get the command
# line from a DLL and thus the proc isn't defined in this environment.
# See https://nim-lang.org/docs/os.html#commandLineParams
when not declared(commandLineParams):
  proc commandLineParams(): seq[string] = discard

proc loadImpl[C, SecondarySources](
    Configuration: typedesc[C],
    cmdLine = commandLineParams(),
    version = "",
    copyrightBanner = "",
    printUsage = true,
    quitOnFailure = true,
    ignoreUnknown = false,
    secondarySourcesRef: ref SecondarySources,
    secondarySources: proc (
        config: Configuration, sources: ref SecondarySources
    ) {.gcsafe, raises: [ConfigurationError].} = nil,
    envVarsPrefix = appInvocation(),
    termWidth = 0
): Configuration {.raises: [ConfigurationError].} =
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
  let (rootCmd, fieldSetters) = configurationRtti(Configuration)
  var fieldCounters: array[fieldSetters.len, int]

  printCmdTree rootCmd

  var activeCmds = @[rootCmd]
  template lastCmd: auto = activeCmds[^1]
  var nextArgIdx = lastCmd.getNextArgIdx(-1)

  var help = ""

  proc suggestCallingHelp =
    errorOutput "Try ", fgCommand, appInvocation() & " --help"
    errorOutput " for more information.\p"
    flushOutputAndQuit QuitFailure

  template fail(args: varargs[untyped]): untyped =
    if quitOnFailure:
      errorOutput args
      errorOutput "\p"
      suggestCallingHelp()
    else:
      # TODO: populate this string
      raise newException(ConfigurationError, "")

  template applySetter(
      conf: Configuration, setterIdx: int, cmdLineVal: string): untyped =
    when defined(nimHasWarnBareExcept):
      {.push warning[BareExcept]:off.}

    try:
      fieldSetters[setterIdx][1](conf, some(cmdLineVal))
      inc fieldCounters[setterIdx]
    except:
      fail("Error while processing the ",
           fgOption, fieldSetters[setterIdx][0],
           "=", cmdLineVal, resetStyle, " parameter: ",
           getCurrentExceptionMsg())

    when defined(nimHasWarnBareExcept):
      {.pop.}

  when hasCompletions:
    template getArgCompletions(opt: OptInfo, prefix: string): seq[string] =
      fieldSetters[opt.idx][2](prefix)

  template required(opt: OptInfo): bool =
    fieldSetters[opt.idx][3] and not opt.hasDefault

  template activateCmd(
      conf: Configuration, discriminator: OptInfo, activatedCmd: CmdInfo) =
    let cmd = activatedCmd
    conf.applySetter(discriminator.idx, if cmd.desc.len > 0: cmd.desc
                                        else: cmd.name)
    activeCmds.add cmd
    nextArgIdx = cmd.getNextArgIdx(-1)

  when hasCompletions:
    type
      ArgKindFilter = enum
        argName
        argAbbr

    proc showMatchingOptions(cmd: CmdInfo, prefix: string, filterKind: set[ArgKindFilter]) =
      var matchingOptions: seq[OptInfo]

      if len(prefix) > 0:
        # Filter the options according to the input prefix
        for opt in cmd.opts:
          if argName in filterKind and len(opt.name) > 0:
            if startsWithIgnoreStyle(opt.name, prefix):
              matchingOptions.add(opt)
          if argAbbr in filterKind and len(opt.abbr) > 0:
            if startsWithIgnoreStyle(opt.abbr, prefix):
              matchingOptions.add(opt)
      else:
        matchingOptions = cmd.opts

      for opt in matchingOptions:
        # The trailing '=' means the switch accepts an argument
        let trailing = if opt.typename != "bool": "=" else: ""

        if argName in filterKind and len(opt.name) > 0:
          try:
            stdout.writeLine("--", opt.name, trailing)
          except IOError:
            discard
        if argAbbr in filterKind and len(opt.abbr) > 0:
          try:
            stdout.writeLine('-', opt.abbr, trailing)
          except IOError:
            discard

    let completion = splitCompletionLine()
    # If we're not asked to complete a command line the result is an empty list
    if len(completion) != 0:
      var cmdStack = @[rootCmd]
      # Try to understand what the active chain of commands is without parsing the
      # whole command line
      for tok in completion[1..^1]:
        if not tok.startsWith('-'):
          let subCmd = findSubCmd(cmdStack[^1], tok)
          if subCmd != nil: cmdStack.add(subCmd)

      let cur_word = completion[^1]
      let prev_word = if len(completion) > 2: completion[^2] else: ""
      let prev_prev_word = if len(completion) > 3: completion[^3] else: ""

      if cur_word.startsWith('-'):
        # Show all the options matching the prefix input by the user
        let isFullName = cur_word.startsWith("--")
        var option_word = cur_word
        option_word.removePrefix('-')

        for i in countdown(cmdStack.len - 1, 0):
          let argFilter =
            if isFullName:
              {argName}
            elif len(cur_word) > 1:
              # If the user entered a single hypen then we show both long & short
              # variants
              {argAbbr}
            else:
              {argName, argAbbr}

          showMatchingOptions(cmdStack[i], option_word, argFilter)
      elif (prev_word.startsWith('-') or
          (prev_word == "=" and prev_prev_word.startsWith('-'))):
        # Handle cases where we want to complete a switch choice
        # -switch
        # -switch=
        var option_word = if len(prev_word) == 1: prev_prev_word else: prev_word
        option_word.removePrefix('-')

        let opt = findOpt(cmdStack, option_word)
        if opt != nil:
          for arg in getArgCompletions(opt, cur_word):
            try:
              stdout.writeLine(arg)
            except IOError:
              discard
      elif cmdStack[^1].hasSubCommands:
        # Show all the available subcommands
        for subCmd in subCmds(cmdStack[^1]):
          if startsWithIgnoreStyle(subCmd.name, cur_word):
            try:
              stdout.writeLine(subCmd.name)
            except IOError:
              discard
      else:
        # Full options listing
        for i in countdown(cmdStack.len - 1, 0):
          showMatchingOptions(cmdStack[i], "", {argName, argAbbr})

      stdout.flushFile()

      return

  proc lazyHelpAppInfo(flags: set[HelpFlag]): HelpAppInfo =
    HelpAppInfo(
      copyrightBanner: copyrightBanner,
      appInvocation: appInvocation(),
      terminalWidth: termWidth,
      hasVersion: version.len > 0,
      flags: flags
    )

  template processHelpAndVersionOptions(optKey, optVal: string) =
    let key = optKey
    let val = optVal
    if cmpIgnoreStyle(key, "help") == 0:
      help.showHelp(lazyHelpAppInfo(optVal.toHelpFlags), activeCmds)
    elif version.len > 0 and cmpIgnoreStyle(key, "version") == 0:
      help.helpOutput version, "\p"
      flushOutputAndQuit QuitSuccess

  for kind, key, val in getopt(cmdLine):
    when key isnot string:
      let key = string(key)
    case kind
    of cmdLongOption, cmdShortOption:
      processHelpAndVersionOptions(key, val)

      var opt = findOpt(activeCmds, key)
      if opt == nil:
        # We didn't find the option.
        # Check if it's from the default command and activate it if necessary:
        let subCmdDiscriminator = lastCmd.getSubCmdDiscriminator
        if subCmdDiscriminator != nil:
          if subCmdDiscriminator.defaultSubCmd != -1:
            let defaultCmd = subCmdDiscriminator.subCmds[subCmdDiscriminator.defaultSubCmd]
            opt = findOpt(defaultCmd.opts, key)
            if opt != nil:
              result.activateCmd(subCmdDiscriminator, defaultCmd)
          else:
            discard

      if opt != nil:
        result.applySetter(opt.idx, val)
      elif not ignoreUnknown:
        fail "Unrecognized option '" & key & "'"

    of cmdArgument:
      if lastCmd.hasSubCommands:
        processHelpAndVersionOptions(key, val)

      block processArg:
        let subCmdDiscriminator = lastCmd.getSubCmdDiscriminator
        if subCmdDiscriminator != nil:
          let subCmd = findCmd(subCmdDiscriminator.subCmds, key)
          if subCmd != nil:
            result.activateCmd(subCmdDiscriminator, subCmd)
            break processArg

        if nextArgIdx == -1:
          fail lastCmd.noMoreArgsError

        result.applySetter(nextArgIdx, key)

        if not fieldSetters[nextArgIdx][4]:
          nextArgIdx = lastCmd.getNextArgIdx(nextArgIdx)

    else:
      discard

  let subCmdDiscriminator = lastCmd.getSubCmdDiscriminator
  if subCmdDiscriminator != nil and
     subCmdDiscriminator.defaultSubCmd != -1 and
     fieldCounters[subCmdDiscriminator.idx] == 0:
    let defaultCmd = subCmdDiscriminator.subCmds[subCmdDiscriminator.defaultSubCmd]
    result.activateCmd(subCmdDiscriminator, defaultCmd)

  # https://github.com/status-im/nim-confutils/pull/109#discussion_r1820076739
  if not isNil(secondarySources):  # Nim v2.0.10: `!= nil` broken in nimscript
    try:
      secondarySources(result, secondarySourcesRef)
    except ConfigurationError as err:
      fail "Failed to load secondary sources: '" & err.msg & "'"

  proc processMissingOpts(
      conf: var Configuration, cmd: CmdInfo) {.raises: [ConfigurationError].} =
    for opt in cmd.opts:
      if fieldCounters[opt.idx] == 0:
        let envKey = constructEnvKey(envVarsPrefix, opt.name)

        try:
          if existsEnv(envKey):
            let envContent = getEnv(envKey)
            conf.applySetter(opt.idx, envContent)
          elif secondarySourcesRef.setters[opt.idx](conf, secondarySourcesRef):
            # all work is done in the config file setter,
            # there is nothing left to do here.
            discard
          elif opt.hasDefault:
            fieldSetters[opt.idx][1](conf, none[string]())
          elif opt.required:
            fail "The required option '" & opt.name & "' was not specified"
        except ValueError as err:
          fail "Option '" & opt.name & "' failed to parse: '" & err.msg & "'"

  for cmd in activeCmds:
    result.processMissingOpts(cmd)

template load*(
    Configuration: type,
    cmdLine = commandLineParams(),
    version = "",
    copyrightBanner = "",
    printUsage = true,
    quitOnFailure = true,
    ignoreUnknown = false,
    secondarySources: untyped = nil,
    envVarsPrefix = appInvocation(),
    termWidth = 0): untyped =
  block:
    let secondarySourcesRef = generateSecondarySources(Configuration)
    loadImpl(Configuration, cmdLine, version,
             copyrightBanner, printUsage, quitOnFailure, ignoreUnknown,
             secondarySourcesRef, secondarySources, envVarsPrefix, termWidth)

func defaults*(Configuration: type): Configuration =
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

    # Replace symbol with ident
    let paramName = ident $skipPragma(arg[0])
    if arg[0].kind == nnkPragmaExpr:
      arg[0][0] = paramName
    else:
      arg[0] = paramName

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
    dispatchCall.add newTree(nnkDotExpr, configVar, paramName)

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

func load*(f: TypedInputFile): f.ContentType =
  when f.Format is Unspecified or f.ContentType is Unspecified:
    {.fatal: "To use `InputFile.load`, please specify the Format and ContentType of the file".}

  when f.Format is Txt:
    # TODO: implement a proper Txt serialization format
    mixin init
    f.ContentType.init readFile(f.string).string
  else:
    mixin loadFile
    loadFile(f.Format, f.string, f.ContentType)

{.pop.}
