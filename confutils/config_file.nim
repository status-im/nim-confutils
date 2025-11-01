# confutils
# Copyright (c) 2018-2024 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  std/[tables, macrocache],
  stew/shims/macros,
  ./utils

{.warning[UnusedImport]:off.}
import
  std/typetraits,
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
    isIgnore: bool
    isFlatten: bool

  ConfFileSectionTail = object
    node: ConfFileSection
    path: seq[ConfFileSection]

  SectionParam = object
    isCommandOrArgument: bool
    isIgnore: bool
    defaultValue: string
    namePragma: string
    isFlatten: bool

{.push gcsafe, raises: [].}

template debugMacroResult(macroName: string) {.dirty.} =
  when defined(debugMacros) or defined(debugConfutils):
    echo "\n-------- ", macroName, " ----------------------"
    echo result.repr

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

proc traverseRecList(recList: NimNode, parent: ConfFileSection): seq[ConfFileSection]

proc traverseIdent(ident: NimNode, typ: NimNode,
                   isDiscriminator: bool, param = SectionParam()): ConfFileSection =
  ident.expectKind nnkIdent
  if param.isFlatten:
    let confTypeImpl = typ.getImpl
    let conf = ConfFileSection(
      fieldName: $ident, typ: typ, isFlatten: param.isFlatten
    )
    conf.children = traverseRecList(confTypeImpl[2][2], conf)
    conf
  else:
    ConfFileSection(
      fieldName: $ident,
      namePragma: param.namePragma, typ: typ,
      defaultValue: param.defaultValue,
      isCommandOrArgument: param.isCommandOrArgument,
      isDiscriminator: isDiscriminator,
      isIgnore: param.isIgnore
    )

proc traversePostfix(postfix: NimNode, typ: NimNode, isDiscriminator: bool,
                     param = SectionParam()): ConfFileSection =
  postfix.expectKind nnkPostfix

  case postfix[1].kind
  of nnkIdent:
    traverseIdent(postfix[1], typ, isDiscriminator, param)
  of nnkAccQuoted:
    traverseIdent(postfix[1][0], typ, isDiscriminator, param)
  else:
    raiseAssert "[Postfix] Unsupported child node:\n" & postfix[1].treeRepr

proc shortEnumName(n: NimNode): NimNode =
  if n.kind == nnkDotExpr:
    n[1]
  else:
    n

proc traversePragma(pragma: NimNode): SectionParam =
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
      elif sym == "ignore":
        result.isIgnore = true
      elif sym == "flatten":
        result.isFlatten = true
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
  let param = traversePragma(pragmaExpr[1])

  case pragmaExpr[0].kind
  of nnkIdent:
    traverseIdent(pragmaExpr[0], typ, isDiscriminator, param)
  of nnkAccQuoted:
    traverseIdent(pragmaExpr[0][0], typ, isDiscriminator, param)
  of nnkPostfix:
    traversePostfix(pragmaExpr[0], typ, isDiscriminator, param)
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
    if child.isCommandOrArgument or child.isIgnore:
      continue
    if child.isCaseBranch:
      if child.children.len > 0:
        var types = generateTypes(child)
        recList.add generateOptionalField(child.fieldName.ident, types[0][0])
        result.add types
    elif child.isFlatten:
      var types = generateTypes(child)
      types[0][2][2].expectKind nnkRecList
      recList.add types[0][2][2]
      for i in 1 ..< types.len:
        result.add types[i]
    else:
      recList.add generateOptionalField(child.getRenamedName.ident, child.typ)
  result[index].putRecList(recList)

proc generateConfTails(
  node: ConfFileSection,
  result: var seq[ConfFileSectionTail],
  pathsCache: var seq[ConfFileSection]
) =
  pathsCache.add node
  if node.children.len == 0:
    result.add ConfFileSectionTail(
      node: node,
      path: pathsCache,
    )
  else:
    for child in node.children:
      generateConfTails(child, result, pathsCache)
  pathsCache.setLen pathsCache.len - 1

proc generateConfTails(root: ConfFileSection, pathsCache: var seq[ConfFileSection]): seq[ConfFileSectionTail] =
  for child in root.children:
    generateConfTails(child, result, pathsCache)

proc fullFieldName(cft: ConfFileSectionTail): string =
  result = ""
  for cf in cft.path:
    if cf.isFlatten:
      result.add cf.fieldName
      result.add "Dot"
  result.add cft.node.fieldName

template cfSetter(a, b: untyped): untyped =
  when a is Option:
    a = some(b)
  else:
    a = b

proc generateSetters(confType, CF: NimNode, cfst: seq[ConfFileSectionTail]):
    (NimNode, NimNode, int) =
  var
    procs = newStmtList()
    assignments = newStmtList()
    numSetters = 0

  let c = "c".ident
  for cf in cfst:
    if cf.node.isCommandOrArgument or cf.node.isIgnore:
      assignments.add quote do:
        result.setters[`numSetters`] = defaultConfigFileSetter
      inc numSetters
      continue

    var fieldPath = c
    var condition: NimNode
    let configVar = ident "config"
    var configField = configVar
    for node in cf.path:
      if node.isFlatten:
        configField = dotExpr(configField, ident node.fieldName)
      else:
        fieldPath = newDotExpr(fieldPath, node.getRenamedName.ident)
        let fieldChecker = newDotExpr(fieldPath, "isSome".ident)
        if condition == nil:
          condition = fieldChecker
        else:
          condition = newNimNode(nnkInfix).add("and".ident).add(condition).add(fieldChecker)
        fieldPath = newDotExpr(fieldPath, "get".ident)
    configField = dotExpr(configField, ident cf.node.fieldName)

    let setterName = genSym(nskProc, cf.fullFieldName() & "CFSetter")
    procs.add quote do:
      proc `setterName`(`configVar`: var `confType`, cf: ref `CF`): bool {.nimcall, gcsafe.} =
        for `c` in cf.data:
          if `condition`:
            cfSetter(`configField`, `fieldPath`)
            return true

    assignments.add quote do:
      result.setters[`numSetters`] = `setterName`
    inc numSetters

  result = (procs, assignments, numSetters)

proc generateConfigFileSetters(confType, optType: NimNode,
                               cfs: seq[ConfFileSectionTail]): NimNode =
  let
    CF = ident "SecondarySources"
    T = confType.getType[1]
    optT = optType[0][0]
    SetterProcType = genSym(nskType, "SetterProcType")
    (setterProcs, assignments, numSetters) = generateSetters(T, CF, cfs)
    stmtList = quote do:
      type
        `SetterProcType` = proc(
          s: var `T`, cf: ref `CF`
        ): bool {.nimcall, gcsafe, raises: [].}

        `CF` = object
           data*: seq[`optT`]
           setters: array[`numSetters`, `SetterProcType`]

      proc defaultConfigFileSetter(
          s: var `T`, cf: ref `CF`
      ): bool {.nimcall, gcsafe, raises: [], used.} =
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
  var
    pathsCache: seq[ConfFileSection]

  result = newTree(nnkStmtList)
  result.add newTree(nnkTypeSection, modelType)

  let confTails = model.generateConfTails(pathsCache)
  result.add generateConfigFileSetters(ConfType, result[^1], confTails)

  debugMacroResult "ConfigFile SecondarySources"

{.pop.}
