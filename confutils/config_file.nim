import
  std/[macrocache, typetraits],
  stew/shims/macros,
  ./defs

#[
Overview of this module:
- Create temporary configuration object with all fields optional.
- Load this temporary object from every registered config files
  including env vars and windows regs if available.
- If the CLI parser detect missing opt, it will try to obtain
  the value from temporary object starting from the first registered
  config file format.
- If none of them have the missing value, it will load the default value
  from `defaultValue` pragma.
]#

const
  configFileRegs = CacheSeq"confutils"

func isOption(n: NimNode): bool =
  if n.kind != nnkBracketExpr: return false
  eqIdent(n[0], "Option")

func makeOption(n: NimNode): NimNode =
  newNimNode(nnkBracketExpr).add(ident("Option"), n)

template objectDecl(a): untyped =
  type a = object

proc putRecList(n: NimNode, recList: NimNode) =
  recList.expectKind nnkRecList
  if n.kind == nnkObjectTy:
    n[2] = recList
    return
  for z in n:
    putRecList(z, recList)

proc generateOptionalField(fieldName: NimNode, fieldType: NimNode): NimNode =
  let right = if isOption(fieldType): fieldType else: makeOption(fieldType)
  newIdentDefs(fieldName, right)

proc optionalizeFields(CF, confType: NimNode): NimNode =
  # Generate temporary object type where
  # all fields are optional.
  result = getAst(objectDecl(CF))
  var recList = newNimNode(nnkRecList)

  var recordDef = getImpl(confType)
  for field in recordFields(recordDef):
    if field.readPragma"command" != nil or
       field.readPragma"argument" != nil:
      continue

    recList.add generateOptionalField(field.name, field.typ)
  result.putRecList(recList)

proc genLoader(i: int, format, ext, path, optType, confType: NimNode): NimNode =
  var pathBlock: NimNode
  if eqIdent(format, "Envvar"):
    pathBlock = quote do:
      block:
        `path`
  elif eqIdent(format, "Winreg"):
    pathBlock = quote do:
      block:
        `path` / vendorName(`confType`) / appName(`confType`)
  else:
    # toml, json, yaml, etc
    pathBlock = quote do:
      block:
        `path` / vendorName(`confType`) / appName(`confType`) & "." & `ext`

  result = quote do:
    let fullPath = `pathBlock`
    try:
      result.data[`i`] = `format`.loadFile(fullPath, `optType`)
    except:
      echo "Error when loading: ", fullPath
      echo getCurrentExceptionMsg()

proc generateSetters(optType, confType, CF: NimNode): (NimNode, NimNode, int) =
  var
    procs = newStmtList()
    assignments = newStmtList()
    recordDef = getImpl(confType)
    numSetters = 0

  procs.add quote do:
    template cfSetter(a, b: untyped): untyped =
      when a is Option:
        a = b
      else:
        a = b.get()

  for field in recordFields(recordDef):
    if field.readPragma"command" != nil or
       field.readPragma"argument" != nil:

      assignments.add quote do:
        result.setters[`numSetters`] = defaultConfigFileSetter

      inc numSetters
      continue

    let setterName = ident($field.name & "CFSetter")
    let fieldName = field.name

    procs.add quote do:
      proc `setterName`(s: var `confType`, cf: `CF`): bool {.
        nimcall, gcsafe .} =
        for c in cf.data:
          if c.`fieldName`.isSome():
            cfSetter(s.`fieldName`, c.`fieldName`)
            return true

    assignments.add quote do:
      result.setters[`numSetters`] = `setterName`

    inc numSetters

  result = (procs, assignments, numSetters)

proc generateConfigFileSetters(optType, CF, confType: NimNode): NimNode =
  let T = confType.getType[1]
  let arrayLen = configFileRegs.len
  let settersType = genSym(nskType, "SettersType")

  var loaderStmts = newStmtList()
  for i in 0..<arrayLen:
    let n = configFileRegs[i]
    let loader = genLoader(i, n[0], n[1], n[2], optType, confType)
    loaderStmts.add quote do: `loader`

  let (procs, assignments, numSetters) = generateSetters(optType, T, CF)

  result = quote do:
    type
      `settersType` = proc(s: var `T`, cf: `CF`): bool {.
        nimcall, gcsafe .}

      `CF` = object
         data: array[`arrayLen`, `optType`]
         setters: array[`numSetters`, `settersType`]

    proc defaultConfigFileSetter(s: var `T`, cf: `CF`): bool {.
        nimcall, gcsafe .} = discard

    `procs`

    proc load(_: type `CF`): `CF` =
      `loaderStmts`
      `assignments`

    load(`CF`)

macro configFile*(confType: type): untyped =
  let T = confType.getType[1]
  let Opt = genSym(nskType, "OptionalFields")
  let CF = genSym(nskType, "ConfigFile")
  result = newStmtList()
  result.add optionalizeFields(Opt, T)
  result.add generateConfigFileSetters(Opt, CF, confType)

macro appendConfigFileFormat*(ConfigFileFormat: type, configExt: string, configPath: untyped): untyped =
  configFileRegs.add newPar(ConfigFileFormat, configExt, configPath)

func appName*(_: type): string =
  # this proc is overrideable
  when false:
    splitFile(os.getAppFilename()).name
  "confutils"

func vendorName*(_: type): string =
  # this proc is overrideable
  "confutils"

func appendConfigFileFormats*(_: type) =
  # this proc is overrideable
  when false:
    # this is a typical example of
    # config file format registration
    appendConfigFileFormat(Envvar, ""):
      "prefix"

    when defined(windows):
      appendConfigFileFormat(Winreg, ""):
        "HKCU" / "SOFTWARE"

      appendConfigFileFormat(Winreg, ""):
        "HKLM" / "SOFTWARE"

      appendConfigFileFormat(Toml, "toml"):
        os.getHomeDir() & ".config"

      appendConfigFileFormat(Toml, "toml"):
        splitFile(os.getAppFilename()).dir

    elif defined(posix):
      appendConfigFileFormat(Toml, "toml"):
        os.getHomeDir() & ".config"

      appendConfigFileFormat(Toml, "toml"):
        "/etc"
