import
  ../confutils

cli do (foo: int, bar: string, args {.argument.}: seq[string]):
  echo "foo = ", foo
  echo "bar = ", bar
  for arg in args: echo "arg ", arg

