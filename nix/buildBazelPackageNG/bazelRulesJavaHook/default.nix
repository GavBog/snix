{ makeSetupHook }:

makeSetupHook {
  name = "rules_java_bazel_hook";
  substitutions = {
    local_java = ./local_java;
  };
} ./setup-hook.sh
