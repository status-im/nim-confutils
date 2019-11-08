## A simple lexer meant to tokenize an input string as a shell would do.
import lexbase
import options
import streams
import os
import strutils

type
  ShellLexer = object of BaseLexer
    preserveTrailingWs: bool
    mergeWordBreaks: bool
    wordBreakChars: string

const
  WORDBREAKS = "\"'@><=;|&(:"
  SAFE_CHARS = {'a'..'z', 'A'..'Z', '0'..'9', '@', '%', '+', '=', ':', ',', '.', '/', '-'}

proc open(l: var ShellLexer, input: Stream, wordBreakChars: string = WORDBREAKS, preserveTrailingWs = true) =
  lexbase.open(l, input)
  l.preserveTrailingWs = preserveTrailingWs
  l.mergeWordBreaks = false
  l.wordBreakChars = wordBreakChars

proc parseQuoted(l: var ShellLexer, pos: int, isSingle: bool, output: var string): int =
  var pos = pos
  while true:
    case l.buf[pos]:
      of '\c': pos = lexbase.handleCR(l, pos)
      of '\L': pos = lexbase.handleLF(l, pos)
      of lexbase.EndOfFile: break
      of '\\':
        # Consume the backslash and the following character
        inc(pos)
        if (isSingle and l.buf[pos] in {'\''}) or 
          (not isSingle and l.buf[pos] in {'$', '`', '\\', '"'}):
          # Escape the character
          output.add(l.buf[pos])
        else:
          # Rewrite the escape sequence as-is
          output.add('\\')
          output.add(l.buf[pos])
        inc(pos)
      of '\"':
        inc(pos)
        if isSingle: output.add('\"')
        else: break
      of '\'':
        inc(pos)
        if isSingle: break
        else: output.add('\'')
      else:
        output.add(l.buf[pos])
        inc(pos)
  return pos

proc getTok(l: var ShellLexer): Option[string] =
  var pos = l.bufpos

  # Skip the initial whitespace
  while true:
    case l.buf[pos]:
      of '\c': pos = lexbase.handleCR(l, pos)
      of '\L': pos = lexbase.handleLF(l, pos)
      of '#':
        # Skip everything until EOF/EOL
        while l.buf[pos] notin {'\c', '\L', lexbase.EndOfFile}:
          inc(pos)
      of lexbase.EndOfFile:
        # If we did eat up some whitespace return an empty token, this is needed
        # to find out if the string ends with whitespace.
        if l.preserveTrailingWs and l.bufpos != pos:
          l.bufpos = pos
          return some("")
        return none(string)
      of ' ', '\t':
        inc(pos)
      else:
        break

  var tokLit = ""
  # Parse the next token
  while true:
    case l.buf[pos]:
      of '\c': pos = lexbase.handleCR(l, pos)
      of '\L': pos = lexbase.handleLF(l, pos)
      of '\'':
        # Single-quoted string
        inc(pos)
        pos = parseQuoted(l, pos, true, tokLit)
      of '"':
        # Double-quoted string
        inc(pos)
        pos = parseQuoted(l, pos, false, tokLit)
      of '\\':
        # Escape sequence
        inc(pos)
        if l.buf[pos] != lexbase.EndOfFile:
          tokLit.add(l.buf[pos])
          inc(pos)
      of '#', ' ', '\t', lexbase.EndOfFile:
        break
      else:
        let ch = l.buf[pos]
        if ch notin l.wordBreakChars:
          tokLit.add(l.buf[pos])
          inc(pos)
        # Merge together runs of adjacent word-breaking characters if requested
        elif l.mergeWordBreaks:
          while l.buf[pos] in l.wordBreakChars:
            tokLit.add(l.buf[pos])
            inc(pos)
          l.mergeWordBreaks = false
          break
        else:
          l.mergeWordBreaks = true
          break

  l.bufpos = pos
  return some(tokLit)

proc splitCompletionLine*(): seq[string] =
  let comp_line = os.getEnv("COMP_LINE")
  var comp_point = parseInt(os.getEnv("COMP_POINT", "0"))

  if comp_point == len(comp_line):
    comp_point -= 1

  if comp_point < 0 or comp_point > len(comp_line):
    return @[]

  # Take the useful part only
  var strm = newStringStream(comp_line[0..comp_point])

  # Split the resulting string
  var l: ShellLexer
  l.open(strm)
  while true:
    let token = l.getTok()
    if token.isNone():
      break
    result.add(token.get())

proc shellQuote*(word: string): string =
  if len(word) == 0:
    return "''"

  if allCharsInSet(word, SAFE_CHARS):
    return word

  result.add('\'')
  for ch in word:
    if ch == '\'': result.add('\\')
    result.add(ch)

  result.add('\'')

proc shellPathEscape*(path: string): string =
  if allCharsInSet(path, SAFE_CHARS):
    return path

  for ch in path:
    if ch notin SAFE_CHARS:
      result.add('\\')
    result.add(ch)

when isMainModule:
  # Test data lifted from python's shlex unit-tests
  const data = """
foo bar|foo|bar|
 foo bar|foo|bar|
 foo bar |foo|bar|
foo   bar    bla     fasel|foo|bar|bla|fasel|
x y  z              xxxx|x|y|z|xxxx|
\x bar|x|bar|
\ x bar| x|bar|
\ bar| bar|
foo \x bar|foo|x|bar|
foo \ x bar|foo| x|bar|
foo \ bar|foo| bar|
foo "bar" bla|foo|bar|bla|
"foo" "bar" "bla"|foo|bar|bla|
"foo" bar "bla"|foo|bar|bla|
"foo" bar bla|foo|bar|bla|
foo 'bar' bla|foo|bar|bla|
'foo' 'bar' 'bla'|foo|bar|bla|
'foo' bar 'bla'|foo|bar|bla|
'foo' bar bla|foo|bar|bla|
blurb foo"bar"bar"fasel" baz|blurb|foobarbarfasel|baz|
blurb foo'bar'bar'fasel' baz|blurb|foobarbarfasel|baz|
""||
''||
foo "" bar|foo||bar|
foo '' bar|foo||bar|
foo "" "" "" bar|foo||||bar|
foo '' '' '' bar|foo||||bar|
\"|"|
"\""|"|
"foo\ bar"|foo\ bar|
"foo\\ bar"|foo\ bar|
"foo\\ bar\""|foo\ bar"|
"foo\\" bar\"|foo\|bar"|
"foo\\ bar\" dfadf"|foo\ bar" dfadf|
"foo\\\ bar\" dfadf"|foo\\ bar" dfadf|
"foo\\\x bar\" dfadf"|foo\\x bar" dfadf|
"foo\x bar\" dfadf"|foo\x bar" dfadf|
\'|'|
'foo\ bar'|foo\ bar|
'foo\\ bar'|foo\\ bar|
"foo\\\x bar\" df'a\ 'df"|foo\\x bar" df'a\ 'df|
\"foo|"foo|
\"foo\x|"foox|
"foo\x"|foo\x|
"foo\ "|foo\ |
foo\ xx|foo xx|
foo\ x\x|foo xx|
foo\ x\x\"|foo xx"|
"foo\ x\x"|foo\ x\x|
"foo\ x\x\\"|foo\ x\x\|
"foo\ x\x\\""foobar"|foo\ x\x\foobar|
"foo\ x\x\\"\'"foobar"|foo\ x\x\'foobar|
"foo\ x\x\\"\'"fo'obar"|foo\ x\x\'fo'obar|
"foo\ x\x\\"\'"fo'obar" 'don'\''t'|foo\ x\x\'fo'obar|don't|
"foo\ x\x\\"\'"fo'obar" 'don'\''t' \\|foo\ x\x\'fo'obar|don't|\|
'foo\ bar'|foo\ bar|
'foo\\ bar'|foo\\ bar|
foo\ bar|foo bar|
:-) ;-)|:-)|;-)|
áéíóú|áéíóú|
"""
  var corpus = newStringStream(data)
  var line = ""
  while corpus.readLine(line):
    let chunks = line.split('|')
    let expr = chunks[0]
    let expected = chunks[1..^2]

    var l: ShellLexer
    var strm = newStringStream(expr)
    var got: seq[string]
    l.open(strm, wordBreakChars="", preserveTrailingWs=false)
    while true:
      let x = l.getTok()
      if x.isNone():
        break
      got.add(x.get())

    if got != expected:
      echo "got ", got
      echo "expected ", expected
      doAssert(false)

  doAssert(quoteWord("") == "''")
  doAssert(quoteWord("\\\"") == "'\\\"'")
  doAssert(quoteWord("foobar") == "foobar")
  doAssert(quoteWord("foo$bar") == "'foo$bar'")
  doAssert(quoteWord("foo bar") == "'foo bar'")
  doAssert(quoteWord("foo'bar") == "'foo\\'bar'")
