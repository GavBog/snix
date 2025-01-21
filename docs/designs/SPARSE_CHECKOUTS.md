NOTE: This proposal is archived. We run `josh` instead, and long-term
might want to integrate per-target dependency analysis with josh's
workspace functionality.

-------------

Below is a prototype for a script to create Git sparse checkouts of the depot.
The script below works today with relatively recent versions of git.

Open items:

 - Read-increment-write the checkout ID from a file in .git.
 - `NICE_CHECKOUT_ROOT` should be a git configuration value.
 - `tvl-get-depends` will be a script that contacts the build farm and asks for
   the closure of a given source directory, using [depot-scan].

```bash
DEPOT_ROOT="${depot.path}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
CLIENT_ROOT="$XDG_DATA_HOME/tvlc/clients"
NICE_CHECKOUT_ROOT="$HOME/tvlc"
CHECKOUT_ID=1
CHECKOUT_NAME=myclient # command line variables

assertAbsolutePath "$CLIENT_ROOT"

mkdir "$CLIENT_ROOT"/"$CHECKOUT_ID"
ln -s "$CLIENT_ROOT"/"$CHECKOUT_ID" "$NICE_CHECKOUT_ROOT"/"$CHECKOUT_NAME"

cd "$DEPOT_ROOT"
git worktree add --no-checkout -b "tvlc-$CHECKOUT_ID" "$CLIENT_ROOT/$CHECKOUT_ID/" canon
# BUG: git not creating the /info/ subdir
mkdir "$DEPOT_ROOT"/.git/worktrees/"$CHECKOUT_ID"/info

cd "$CLIENT_ROOT/$CHECKOUT_ID"
git sparse-checkout init --cone
git sparse-checkout set "$TARGET_DIR" nix/readTree overrides
tvl-get-depends "$TARGET_DIR" | xargs git sparse-checkout add

cd "$NICE_CHECKOUT_ROOT"/"$CHECKOUT_NAME"
```

[depot-scan]: ../../users/edef/depot-scan
