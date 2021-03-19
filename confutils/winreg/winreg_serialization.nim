import
  stew/shims/macros,
  serialization, ./reader, ./writer, ./utils, ./types

export
  serialization, reader, writer, types

serializationFormat Winreg

Winreg.setReader WinregReader
Winreg.setWriter WinregWriter, PreferredOutput = void

template supports*(_: type Winreg, T: type): bool =
  # The Winreg format should support every type
  true

template decode*(_: type Winreg,
                 hKey: HKEY,
                 path: string,
                 RecordType: distinct type,
                 params: varargs[untyped]): auto =
  mixin init, ReaderType

  {.noSideEffect.}:
    var reader = unpackArgs(init, [WinregReader, hKey, path, params])
    reader.readValue(RecordType)

template encode*(_: type Winreg,
                 hKey: HKEY,
                 path: string,
                 value: auto,
                 params: varargs[untyped]) =
  mixin init, WriterType, writeValue

  {.noSideEffect.}:
    var writer = unpackArgs(init, [WinregWriter, hKey, path, params])
    writeValue writer, value

template loadFile*(_: type Winreg,
                   filename: string,
                   RecordType: distinct type,
                   params: varargs[untyped]): auto =
  mixin init, ReaderType, readValue

  # filename should be a Windows Registry path
  # such as "HKEY_CLASSES_ROOT\\SOFTWARE\\Nimbus"
  # or "HKCU\\SOFTWARE\\Nimbus"
  let (hKey, path) = parseWinregPath(filename)
  var reader = unpackArgs(init, [WinregReader, hKey, path, params])
  reader.readValue(RecordType)

template saveFile*(_: type Winreg, filename: string, value: auto, params: varargs[untyped]) =
  mixin init, WriterType, writeValue

  # filename should be a Windows Registry path
  let (hKey, path) = parseWinregPath(filename)
  var writer = unpackArgs(init, [WinregWriter, hKey, path, params])
  writer.writeValue(value)
