import 
  ../../confutils, 
  ../../confutils/defs
  
type
  TestConf* = object
    dataDir* {.abbr: "d" }: OutDir
    importDir* {.abbr: "d" }: OutDir

let c = TestConf.load()
