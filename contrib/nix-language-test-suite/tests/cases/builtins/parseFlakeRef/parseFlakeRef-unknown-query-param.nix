# Test extraneous query params
#
# This is a separate test case from the others as Lix is more strict here than Cppnix.
builtins.parseFlakeRef "github:user/project/branch?foo=1"
