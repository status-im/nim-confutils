import
  serialization/errors

type
  HKEY*    = distinct uint
  RegType* = distinct int32
  WinregError* = object of SerializationError

const
  HKEY_CLASSES_ROOT*  = HKEY(0x80000000'u)
  HKEY_CURRENT_USER*  = HKEY(0x80000001'u)
  HKEY_LOCAL_MACHINE* = HKEY(0x80000002'u)
  HKEY_USERS*         = HKEY(0x80000003'u)

  HKLM* = HKEY_LOCAL_MACHINE
  HKCU* = HKEY_CURRENT_USER
  HKCR* = HKEY_CLASSES_ROOT
  HKU*  = HKEY_USERS

proc `==`*(a, b: HKEY): bool {.borrow.}
proc `==`*(a, b: RegType): bool {.borrow.}
