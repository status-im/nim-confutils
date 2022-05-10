import
  std/[tables, macrocache, typetraits],
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

type
  ConfFileSection = ref object
    children: seq[ConfFileSection]
    fieldName: string
    namePragma: string
    typ: NimNode
    defaultValue: string
    isCommandOrArgument: bool
    isCaseBranch: bool
    isDiscriminator: bool

  GeneratedFieldInfo = tuple
    isCommandOrArgument: bool
    path: seq[string]

  OriginalToGeneratedFields = OrderedTable[string, GeneratedFieldInfo]

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

proc traverseIdent(ident: NimNode, typ: NimNode, isDiscriminator: bool,
                   isCommandOrArgument = false, defaultValue = "",
                   namePragma = ""): ConfFileSection =
  ident.expectKind nnkIdent
  ConfFileSection(fieldName: $ident, namePragma: namePragma, typ: typ,
                  defaultValue: defaultValue, isCommandOrArgument: isCommandOrArgument,
                  isDiscriminator: isDiscriminator)

proc traversePostfix(postfix: NimNode, typ: NimNode, isDiscriminator: bool,
                     isCommandOrArgument = false, defaultValue = "",
                     namePragma = ""): ConfFileSection =
  postfix.expectKind nnkPostfix

  case postfix[1].kind
  of nnkIdent:
    traverseIdent(postfix[1], typ, isDiscriminator, isCommandOrArgument,
                  defaultValue, namePragma)
  of nnkAccQuoted:
    traverseIdent(postfix[1][0], typ, isDiscriminator, isCommandOrArgument,
                  defaultValue, namePragma)
  else:
    raiseAssert "[Postfix] Unsupported child node:\n" & postfix[1].treeRepr

proc shortEnumName(n: NimNode): NimNode =
  if n.kind == nnkDotExpr:
    n[1]
  else:
    n

proc traversePragma(pragma: NimNode):
    tuple[isCommandOrArgument: bool, defaultValue, namePragma: string] =
  pragma.expectKind nnkPragma
  var child: NimNode

  for childNode in pragma:
    child = childNode

    if child.kind == nnkCall:
      # A custom pragma was used more than once (e.g.: {.pragma: posixOnly, hidden.}) and the
      # AST is now:
      # ```
      # Call
      #   Sym "hidden"
      # ```
      child = child[0]

    case child.kind
    of nnkSym:
      let sym = $child
      if sym == "command" or sym == "argument":
        result.isCommandOrArgument = true
    of nnkExprColonExpr:
      let pragma = $child[0]
      if pragma == "defaultValue":
        result.defaultValue = repr(shortEnumName(child[1]))
      elif pragma == "name":
        result.namePragma = $child[1]
    else:
      raiseAssert "[Pragma] Unsupported child node:\n" & child.treeRepr

proc traversePragmaExpr(pragmaExpr: NimNode, typ: NimNode,
                        isDiscriminator: bool): ConfFileSection =
  pragmaExpr.expectKind nnkPragmaExpr
  let (isCommandOrArgument, defaultValue, namePragma) =
    traversePragma(pragmaExpr[1])

  case pragmaExpr[0].kind
  of nnkIdent:
    traverseIdent(pragmaExpr[0], typ, isDiscriminator, isCommandOrArgument,
                  defaultValue, namePragma)
  of nnkAccQuoted:
    traverseIdent(pragmaExpr[0][0], typ, isDiscriminator, isCommandOrArgument,
                  defaultValue, namePragma)
  of nnkPostfix:
    traversePostfix(pragmaExpr[0], typ, isDiscriminator, isCommandOrArgument,
                    defaultValue, namePragma)
  else:
    raiseAssert "[PragmaExpr] Unsupported expression:\n" & pragmaExpr.treeRepr

proc traverseIdentDefs(identDefs: NimNode, parent: ConfFileSection,
                       isDiscriminator: bool): seq[ConfFileSection] =
  identDefs.expectKind nnkIdentDefs
  doAssert identDefs.len > 2, "This kind of node must have at least 3 children."
  let typ = identDefs[^2]
  for child in identDefs:
    case child.kind
    of nnkIdent:
      result.add traverseIdent(child, typ, isDiscriminator)
    of nnkAccQuoted:
      result.add traverseIdent(child[0], typ, isDiscriminator)
    of nnkPostfix:
      result.add traversePostfix(child, typ, isDiscriminator)
    of nnkPragmaExpr:
      result.add traversePragmaExpr(child, typ, isDiscriminator)
    of nnkBracketExpr, nnkSym, nnkEmpty, nnkInfix, nnkCall, nnkDotExpr:
      discard
    else:
      raiseAssert "[IdentDefs] Unsupported child node:\n" & child.treeRepr

proc traverseRecList(recList: NimNode, parent: ConfFileSection): seq[ConfFileSection]

proc traverseOfBranch(ofBranch: NimNode, parent: ConfFileSection): ConfFileSection =
  ofBranch.expectKind nnkOfBranch
  result = ConfFileSection(fieldName: repr(shortEnumName(ofBranch[0])), isCaseBranch: true)
  for child in ofBranch:
    case child.kind:
    of nnkIdent, nnkDotExpr, nnkAccQuoted:
      discard
    of nnkRecList:
      result.children.add traverseRecList(child, result)
    else:
      raiseAssert "[OfBranch] Unsupported child node:\n" & child.treeRepr

proc traverseRecCase(recCase: NimNode, parent: ConfFileSection): seq[ConfFileSection] =
  recCase.expectKind nnkRecCase
  for child in recCase:
    case child.kind
    of nnkIdentDefs:
      result.add traverseIdentDefs(child, parent, true)
    of nnkOfBranch:
      result.add traverseOfBranch(child, parent)
    else:
      raiseAssert "[RecCase] Unsupported child node:\n" & child.treeRepr

proc traverseRecList(recList: NimNode, parent: ConfFileSection): seq[ConfFileSection] =
  recList.expectKind nnkRecList
  for child in recList:
    case child.kind
    of nnkIdentDefs:
      result.add traverseIdentDefs(child, parent, false)
    of nnkRecCase:
      result.add traverseRecCase(child, parent)
    of nnkNilLit:
      discard
    else:
      raiseAssert "[RecList] Unsupported child node:\n" & child.treeRepr

proc normalize(root: ConfFileSection) =
  ## Moves the default case branches children one level upper in the hierarchy.
  ## Also removes case branches without children.
  var children: seq[ConfFileSection]
  var defaultValue = ""
  for child in root.children:
    normalize(child)
    if child.isDiscriminator:
      defaultValue = child.defaultValue
    if child.isCaseBranch and child.fieldName == defaultValue:
      for childChild in child.children:
        children.add childChild
      child.children = @[]
    elif child.isCaseBranch and child.children.len == 0:
      discard
    else:
      children.add child
  root.children = children

proc generateConfigFileModel(ConfType: NimNode): ConfFileSection =
  let confTypeImpl = ConfType.getType[1].getImpl
  result = ConfFileSection(fieldName: $confTypeImpl[0])
  result.children = traverseRecList(confTypeImpl[2][2], result)
  result.normalize

proc getRenamedName(node: ConfFileSection): string =
  if node.namePragma.len == 0: node.fieldName else: node.namePragma

proc generateTypes(root: ConfFileSection): seq[NimNode] =
  let index = result.len
  result.add getAst(objectDecl(genSym(nskType, root.fieldName)))[0]
  var recList = newNimNode(nnkRecList)
  for child in root.children:
    if child.isCommandOrArgument:
      continue
    if child.isCaseBranch:
      if child.children.len > 0:
        var types = generateTypes(child)
        recList.add generateOptionalField(child.fieldName.ident, types[0][0])
        result.add types
    else:
      recList.add generateOptionalField(child.getRenamedName.ident, child.typ)
  result[index].putRecList(recList)

proc generateSettersPaths(node: ConfFileSection, result: var OriginalToGeneratedFields) =
  var path {.global.}: seq[string]
  path.add node.getRenamedName
  if node.children.len == 0:
    result[node.fieldName] = (node.isCommandOrArgument, path)
  else:
    for child in node.children:
      generateSettersPaths(child, result)
  path.del path.len - 1

proc generateSettersPaths(root: ConfFileSection): OriginalToGeneratedFields =
  for child in root.children:
    generateSettersPaths(child, result)

template cfSetter(a, b: untyped): untyped =
  when a is Option:
    a = some(b)
  else:
    a = b

proc generateSetters(confType, CF: NimNode, fieldsPaths: OriginalToGeneratedFields):
    (NimNode, NimNode, int) =
  var
    procs = newStmtList()
    assignments = newStmtList()
    numSetters = 0

  let c = "c".ident
  for field, (isCommandOrArgument, path) in fieldsPaths:
    if isCommandOrArgument:
      assignments.add quote do:
        result.setters[`numSetters`] = defaultConfigFileSetter
      inc numSetters
      continue

    var fieldPath = c
    var condition: NimNode
    for fld in path:
      fieldPath = newDotExpr(fieldPath, fld.ident)
      let fieldChecker = newDotExpr(fieldPath, "isSome".ident)
      if condition == nil:
        condition = fieldChecker
      else:
        condition = newNimNode(nnkInfix).add("and".ident).add(condition).add(fieldChecker)
      fieldPath = newDotExpr(fieldPath, "get".ident)

    let setterName = genSym(nskProc, field & "CFSetter")
    let fieldIdent = field.ident
    procs.add quote do:
      proc `setterName`(s: var `confType`, cf: ref `CF`): bool {.nimcall, gcsafe.} =
        for `c` in cf.data:
          if `condition`:
            cfSetter(s.`fieldIdent`, `fieldPath`)
            return true

    assignments.add quote do:
      result.setters[`numSetters`] = `setterName`
    inc numSetters

  result = (procs, assignments, numSetters)

proc generateConfigFileSetters(confType, optType: NimNode,
                               fieldsPaths: OriginalToGeneratedFields): NimNode =
  let
    CF = ident "SecondarySources"
    T = confType.getType[1]
    optT = optType[0][0]
    SetterProcType = genSym(nskType, "SetterProcType")
    (setterProcs, assignments, numSetters) = generateSetters(T, CF, fieldsPaths)
    stmtList = quote do:
      type
        `SetterProcType` = proc(s: var `T`, cf: ref `CF`): bool {.nimcall, gcsafe.}

        `CF` = object
           data*: seq[`optT`]
           setters: array[`numSetters`, `SetterProcType`]

      proc defaultConfigFileSetter(s: var `T`, cf: ref `CF`): bool {.nimcall, gcsafe.} =
        discard

      `setterProcs`

      proc new(_: type `CF`): ref `CF` =
        new result
        `assignments`

      new(`CF`)

  stmtList

macro generateSecondarySources*(ConfType: type): untyped =
  let
    model = generateConfigFileModel(ConfType)
    modelType = generateTypes(model)

  result = newTree(nnkStmtList)
  result.add newTree(nnkTypeSection, modelType)

  let settersPaths = model.generateSettersPaths
  result.add generateConfigFileSetters(ConfType, result[^1], settersPaths)
