## What?

The way to test --help output changes is to remove all files under `snapshot`
and run `./tests/test_help.nim` so the snapshots get generated again with
the new content. Then you can check what changed compared to the original file.

The snapshots are the output of the `*.nim --help` programs in this directory.

Once your done commit the changes including the new snapshots.
