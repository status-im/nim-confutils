import
  stew/shims/macros,
  serialization, ./reader, ./writer, ./utils

export
  serialization, reader, writer, utils

serializationFormat Winreg,
                    Reader = WinregReader,
                    Writer = WinregWriter,
                    PreferedOutput = void

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
                 value: auto,
                 hKey: HKEY,
                 path: string,
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

  let (hKey, path) = parseWinregPath(filename)
  var reader = unpackArgs(init, [WinregReader, hKey, path, params])
  reader.readValue(RecordType)

template saveFile*(Format: type, filename: string, value: auto, params: varargs[untyped]) =
  mixin init, WriterType, writeValue

  let (hKey, path) = parseWinregPath(filename)
  var writer = unpackArgs(init, [WinregWriter, hKey, path, params])
  writer.writeValue(value)
