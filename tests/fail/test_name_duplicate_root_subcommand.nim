import 
  ../../confutils, 
  ../../confutils/defs
  
type
  Command = enum
    noCommand
    
  TestConf* = object
    dataDir* {.name: "data-dir" }: OutDir    
    
    case cmd* {.
      command
      defaultValue: noCommand }: Command

    of noCommand:
      importDir* {.name: "data-dir" }: OutDir

let c = TestConf.load()
