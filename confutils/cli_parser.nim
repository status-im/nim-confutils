# Copyright 2018 Status Research & Development GmbH
# Parts taken from Nim's Runtime Library (c) Copyright 2015 Andreas Rumpf

type
  CmdLineKind* = enum         ## The detected command line token.
    cmdEnd,                   ## End of command line reached
    cmdArgument,              ## An argument such as a filename
    cmdLongOption,            ## A long option such as --option
    cmdShortOption            ## A short option such as -c

  TriBool* = enum
    Yes,
    No,
    Maybe

  OptParser* = object of RootObj ## Implementation of the command line parser.
    pos*: int
    inShortState: bool
    allowWhitespaceAfterColon: bool
    shortNoVal: set[char]
    longNoVal: seq[string]
    cmds: seq[string]
    idx: int
    kind*: CmdLineKind        ## The detected command line token
    key*, val*: TaintedString ## Key and value pair; the key is the option
                              ## or the argument, and the value is not "" if
                              ## the option was given a value

type
  FieldReader*[ConfigType] = proc (conf: var ConfigType, val: TaintedString)
                                  {.gcsafe, raises: [Defect, CatchableError].}

  Transition = object
    nextState: uint16
    fieldReaderState: FieldReaderState

  CliDFA*[ConfigType] = object
    flagNames: Table[string, int] # TODO replace this with perfect hashing
    
    fieldReaders: seq[FieldReader[configType]]
      ## 

    FieldReaderState = distinct uint16
      # 15 bits for the field reader index
      # 1 bits to determine the type of the field reader (optional or not)
      # The special value `noFieldReader` indicates that there is no
      # current field Reader

    numStates: int

    stateTransitions: seq[Transition]
      ## You can think of this as a two dimentional array where we specify
      ## how each flag index is handled in each state.
      ##
      ## The flags that are invalid in a particular state are marked with
      ## the `invalidTransition` value. Otherwise, the transition indicates
      ## how the state
    
  CliParserState = object
    currentState: uint16
    fieldReaderState: FieldReaderState

const 
  fieldNotExpected* = FieldReaderState max(uint16)
  invalidTransition* = Transition(nextState: -1, fieldReaderState: fieldNotExpected)
  
template isFieldExpected(stateParam: FieldReaderState): TriBool =
  let state = uint16(stateParam)
  if state == uint16(fieldNotExpected):
    No
  elif (state and 1) != 0:
    Yes:
  else:
    Maybe

template readerIdx(state: FieldReaderState) =
  uint16(state) shr 1

template init(T: type FieldReaderState, idx: uint16, valueOptional: bool): T =
  T((idx shl 1) or uint16(valueOptional))

proc parseWord(s: string, i: int, w: var string,
               delim: set[char] = {'\t', ' '}): int =
  result = i
  if result < s.len and s[result] == '\"':
    inc(result)
    while result < s.len:
      if s[result] == '"':
        inc result
        break
      add(w, s[result])
      inc(result)
  else:
    while result < s.len and s[result] notin delim:
      add(w, s[result])
      inc(result)

proc initOptParser*(cmds: seq[string], shortNoVal: set[char]={},
                    longNoVal: seq[string] = @[];
                    allowWhitespaceAfterColon = true): OptParser =
  result.pos = 0
  result.idx = 0
  result.inShortState = false
  result.shortNoVal = shortNoVal
  result.longNoVal = longNoVal
  result.allowWhitespaceAfterColon = allowWhitespaceAfterColon
  result.cmds = cmds
  result.kind = cmdEnd
  result.key = TaintedString""
  result.val = TaintedString""

proc handleShortOption(p: var OptParser; cmd: string) =
  var i = p.pos
  p.kind = cmdShortOption
  if i < cmd.len:
    add(p.key.string, cmd[i])
    inc(i)
  p.inShortState = true
  while i < cmd.len and cmd[i] in {'\t', ' '}:
    inc(i)
    p.inShortState = false
  if i < cmd.len and cmd[i] in {':', '='} or
      card(p.shortNoVal) > 0 and p.key.string[0] notin p.shortNoVal:
    if i < cmd.len and cmd[i] in {':', '='}:
      inc(i)
    p.inShortState = false
    while i < cmd.len and cmd[i] in {'\t', ' '}: inc(i)
    p.val = TaintedString substr(cmd, i)
    p.pos = 0
    inc p.idx
  else:
    p.pos = i
  if i >= cmd.len:
    p.inShortState = false
    p.pos = 0
    inc p.idx

proc next*(p: var OptParser) =
  ## Parses the next token.
  ##
  ## ``p.kind`` describes what kind of token has been parsed. ``p.key`` and
  ## ``p.val`` are set accordingly.
  if p.idx >= p.cmds.len:
    p.kind = cmdEnd
    return

  var i = p.pos
  while i < p.cmds[p.idx].len and p.cmds[p.idx][i] in {'\t', ' '}: inc(i)
  p.pos = i
  setLen(p.key, 0)
  setLen(p.val, 0)
  if p.inShortState:
    p.inShortState = false
    if i >= p.cmds[p.idx].len:
      inc(p.idx)
      p.pos = 0
      if p.idx >= p.cmds.len:
        p.kind = cmdEnd
        return
    else:
      handleShortOption(p, p.cmds[p.idx])
      return

  if i < p.cmds[p.idx].len and p.cmds[p.idx][i] == '-':
    inc(i)
    if i < p.cmds[p.idx].len and p.cmds[p.idx][i] == '-':
      p.kind = cmdLongOption
      inc(i)
      i = parseWord(p.cmds[p.idx], i, p.key, {' ', '\t', ':', '='})
      while i < p.cmds[p.idx].len and p.cmds[p.idx][i] in {'\t', ' '}: inc(i)
      if i < p.cmds[p.idx].len and p.cmds[p.idx][i] in {':', '='}:
        inc(i)
        while i < p.cmds[p.idx].len and p.cmds[p.idx][i] in {'\t', ' '}: inc(i)
        # if we're at the end, use the next command line option:
        if p.allowWhitespaceAfterColon and i >= p.cmds[p.idx].len and
           p.idx + 1 < p.cmds.len and p.cmds[p.idx + 1][0] != '-':
          inc p.idx
          i = 0
        if p.idx < p.cmds.len:
          p.val = TaintedString p.cmds[p.idx].substr(i)
      elif len(p.longNoVal) > 0 and p.key.string notin p.longNoVal and p.idx+1 < p.cmds.len:
        p.val = TaintedString p.cmds[p.idx+1]
        inc p.idx
      else:
        p.val = TaintedString""
      inc p.idx
      p.pos = 0
    else:
      p.pos = i
      handleShortOption(p, p.cmds[p.idx])
  else:
    p.kind = cmdArgument
    p.key = TaintedString p.cmds[p.idx]
    inc p.idx
    p.pos = 0

iterator getopt*(p: var OptParser): tuple[kind: CmdLineKind, key, val: TaintedString] =
  p.pos = 0
  p.idx = 0
  while true:
    next(p)
    if p.kind == cmdEnd: break
    yield (p.kind, p.key, p.val)

iterator getopt*(cmds: seq[string],
                 shortNoVal: set[char]={}, longNoVal: seq[string] = @[]):
           tuple[kind: CmdLineKind, key, val: TaintedString] =
  var p = initOptParser(cmds, shortNoVal=shortNoVal, longNoVal=longNoVal)
  while true:
    next(p)
    if p.kind == cmdEnd: break
    yield (p.kind, p.key, p.val)

