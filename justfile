fmt:
    runic --inplace src test

fmt-check:
    runic --check src test

# Compile `test/juliac` with `--trim=safe` and check the binary prints its rendered docstrings.
juliac:
    juliac --output-exe juliacapp --bundle test/juliac/build --trim=safe --experimental test/juliac
    test/juliac/build/bin/juliacapp | diff test/juliac/expected.txt -
