# confutils
# Copyright (c) 2018-2026 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  std/[tables, macrocache, options],
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

{.push gcsafe, raises: [].}

template debugMacroResult(macroName: string) {.dirty.} =
  when defined(debugMacros) or defined(debugConfutils):
    echo "\n-------- ", macroName, " ----------------------"
    echo result.repr

template optionalType(typ: untyped): type =
  when typ is Option: typ else: Option[typ]

template objectDecl(a): untyped =
  type a = object

proc putRecList(n: NimNode, recList: NimNode) =
  recList.expectKind nnkRecList
  if n.kind == nnkObjectTy:
    n[2] = recList
    return
  for z in n:
    putRecList(z, recList)

func generateOptionalField(fieldName: NimNode, fieldType: NimNode): NimNode =
  newIdentDefs(fieldName, newCall(bindSym"optionalType", fieldType))

proc addFieldSections(parent: ConfFileSection, typ: NimNode)

proc fieldSection(field: FieldDescription): ConfFileSection =
  if field.hasPragma"flatten":
    result = ConfFileSection(
      fieldName: $field.name, typ: field.typ, isFlatten: true)
    result.addFieldSections(field.typ)
  else:
    let
      namePragma = field.readPragmaValue"name"
      defaultValue = field.readPragmaValue"defaultValue"
    result = ConfFileSection(
      fieldName: $field.name,
      namePragma: if namePragma != nil: $namePragma else: "",
      typ: field.typ,
      defaultValue:
        if defaultValue != nil: repr(shortEnumName(defaultValue)) else: "",
      isCommandOrArgument:
        field.hasPragma"command" or field.hasPragma"argument",
      isDiscriminator: field.isDiscriminator,
      isIgnore: field.hasPragma"ignore")

func branchSection(field: FieldDescription): ConfFileSection =
  ConfFileSection(
    fieldName: repr(shortEnumName(field.caseBranch[0])), isCaseBranch: true)

proc addFieldSections(parent: ConfFileSection, typ: NimNode) =
  var
    discriminatorParents: Table[string, ConfFileSection]
    branchSections: Table[(string, string), ConfFileSection]
  for field in recordFields(typ):
    var section = parent
    if field.caseField != nil:
      if field.caseBranch.kind != nnkOfBranch:
        error "Sub-command parameters cannot appear in an else branch. " &
              "Please specify the sub-command branch precisely",
              field.caseBranch[0]
      let key = ($field.caseFieldName, repr(field.caseBranchValues))
      section = branchSections.getOrDefault(key)
      if section == nil:
        section = field.branchSection()
        discriminatorParents.getOrDefault(key[0]).children.add section
        branchSections[key] = section
    section.children.add fieldSection(field)
    if field.isDiscriminator:
      discriminatorParents[$field.name] = section

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
  result = ConfFileSection(fieldName: ConfType.repr)
  result.addFieldSections(ConfType)
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
    T = confType
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
