import
  ../confutils

cli do (foo: int, bar: string, withBaz: bool, args {.argument.}: seq[string]):
  echo "foo = ", foo
  echo "bar = ", bar
  echo "baz = ", withBaz
  for arg in args: echo "arg ", arg

