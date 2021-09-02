import 
  ../../confutils, 
  ../../confutils/defs
  
type
  Command = enum
    noCommand
    
  TestConf* = object
    dataDir* {.abbr: "d" }: OutDir    
    
    case cmd* {.
      command
      defaultValue: noCommand }: Command

    of noCommand:
      importDir* {.abbr: "i" }: OutDir
      importKey* {.abbr: "i" }: OutDir

let c = TestConf.load()
