import 
  ../../confutils, 
  ../../confutils/defs
  
type
  TestConf* = object
    dataDir* {.name: "data-dir" }: OutDir
    importDir* {.name: "data-dir" }: OutDir

let c = TestConf.load()
