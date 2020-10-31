import
  strutils,
  ./types

type
  SomePrimitives* = SomeInteger | enum | bool | SomeFloat | char

const
  REG_SZ*     = RegType(1)
  REG_BINARY* = RegType(3)
  REG_DWORD*  = RegType(4)
  REG_QWORD*  = RegType(11)

  RT_SZ*     = 0x00000002
  RT_BINARY* = 0x00000008
  RT_DWORD*  = 0x00000010
  RT_QWORD*  = 0x00000040
  RT_ANY*    = 0x0000ffff

proc regGetValue(hKey: HKEY, lpSubKey, lpValue: cstring,
                 dwFlags: int32, pdwType: ptr RegType,
                 pvData: pointer, pcbData: ptr int32): int32 {.
  importc: "RegGetValueA", dynlib: "Advapi32.dll", stdcall.}

proc regSetValue(hKey: HKEY, lpSubKey, lpValueName: cstring,
                 dwType: RegType; lpData: pointer; cbData: int32): int32 {.
  importc: "RegSetKeyValueA", dynlib: "Advapi32.dll", stdcall.}

template call(f) =
  if f != 0:
    return false

proc setValue*(hKey: HKEY, path, key: string, val: SomePrimitives): bool =
  when sizeof(val) < 8:
    var dw = cast[int32](val)
    call regSetValue(hKey, path, key, REG_DWORD, dw.addr, sizeof(dw).int32)
  else:
    var dw = cast[int64](val)
    call regSetValue(hKey, path, key, REG_QWORD, dw.addr, sizeof(dw).int32)
  result = true

proc setValue*[T: SomePrimitives](hKey: HKEY, path, key: string, val: openArray[T]): bool =
  call regSetValue(hKey, path, key, REG_BINARY, val[0].unsafeAddr, int32(val.len * sizeof(T)))
  result = true

proc getValue*(hKey: HKEY, path, key: string, outVal: var string): bool =
  var size: int32
  call regGetValue(hKey, path, key, RT_BINARY, nil, nil, addr size)
  outVal.setLen(size)
  call regGetValue(hKey, path, key, RT_BINARY, nil, outVal[0].addr, addr size)
  result = true

proc getValue*[T: SomePrimitives](hKey: HKEY, path, key: string, outVal: var seq[T]): bool =
  var size: int32
  call regGetValue(hKey, path, key, RT_BINARY, nil, nil, addr size)
  outVal.setLen(size div sizeof(T))
  call regGetValue(hKey, path, key, RT_BINARY, nil, outVal[0].addr, addr size)
  result = true

proc getValue*[N, T: SomePrimitives](hKey: HKEY, path, key: string, outVal: var array[N, T]): bool =
  var size: int32
  call regGetValue(hKey, path, key, RT_BINARY, nil, nil, addr size)
  if outVal.len != size div sizeof(T):
    return false
  call regGetValue(hKey, path, key, RT_BINARY, nil, outVal[0].addr, addr size)
  result = true

proc getValue*(hKey: HKEY, path, key: string, outVal: var SomePrimitives): bool =
  when sizeof(outVal) < 8:
    type T = type outVal
    var val: int32
    var valSize = sizeof(val).int32
    call regGetValue(hKey, path, key, RT_DWORD, nil, val.addr, valSize.addr)
    outVal = cast[T](val)
  else:
    var valSize = sizeof(outVal).int32
    call regGetValue(hKey, path, key, RT_QWORD, nil, outVal.addr, valSize.addr)
  result = true

proc pathExists*(hKey: HKEY, path, key: string): bool {.inline.} =
  result = regGetValue(hKey, path, key, RT_ANY, nil, nil, nil) == 0

proc parseWinregPath*(input: string): (HKEY, string) =
  let pos = input.find('\\')
  if pos < 0: return

  result[1] = input.substr(pos + 1)
  case input.substr(0, pos - 1)
  of "HKEY_CLASSES_ROOT", "HKCR":
    result[0] = HKCR
  of "HKEY_CURRENT_USER", "HKCU":
    result[0] = HKCU
  of "HKEY_LOCAL_MACHINE", "HKLM":
    result[0] = HKLM
  of "HKEY_USERS", "HKU":
    result[0] = HKU
  else:
    discard

proc `$`*(hKey: HKEY): string =
  case hKey
  of HKCR: result = "HKEY_CLASSES_ROOT"
  of HKCU: result = "HKEY_CURRENT_USER"
  of HKLM: result = "HKEY_LOCAL_MACHINE"
  of HKU : result = "HKEY_USERS"
  else: discard

template uTypeIsPrimitives*[T](_: type seq[T]): bool =
  when T is SomePrimitives:
    true
  else:
    false

template uTypeIsPrimitives*[N, T](_: type array[N, T]): bool =
  when T is SomePrimitives:
    true
  else:
    false

template uTypeIsPrimitives*[T](_: type openArray[T]): bool =
  when T is SomePrimitives:
    true
  else:
    false

template uTypeIsRecord*(_: typed): bool =
  false

template uTypeIsRecord*[T](_: type seq[T]): bool =
  when T is (object or tuple):
    true
  else:
    false

template uTypeIsRecord*[N, T](_: type array[N, T]): bool =
  when T is (object or tuple):
    true
  else:
    false

func constructPath*(root: string, keys: openArray[string]): string =
  if keys.len <= 1:
    return root
  var size = root.len + 1
  for i in 0..<keys.len-1:
    inc(size, keys[i].len + 1)
  result = newStringOfCap(size)
  result.add root
  result. add '\\'
  for i in 0..<keys.len-1:
    result.add keys[i]
    if i < keys.len-2:
      result. add '\\'
