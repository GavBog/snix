#!/usr/bin/env BQN
# SPDX-FileCopyrightText: Copyright © 2024-2025 by sterni
# SPDX-License-Identifier: MIT
#
# Generate Compose Sequences for /lib/keyboard that enable entering BQN specific
# Unicode characters using their familiar key combinations in Plan 9 programs.

# TODO(sterni): move these helper functions somewhere reusable
LogBase ← ÷˜○•math.Log10
Digs ← (⌊ 1⊸+)∘LogBase
DivMod ← ⌊∘÷˜⋈|
hd←"0123456789ABCDEF"
ToHex ← {hd⊏˜(16⊸DivMod⟜⊑ ∾ 1⊸↓)⍟(-⟜1 𝕨⊸⌈⟜(16⊸Digs)) 𝕩} # 𝕨 is the min amount of digits
FromHex ← {+´(16⋆⌽↕≠𝕩)×hd⊐𝕩}
IsAscii ← 127⊸≥-⟜@

# Parse CLI
opts ← {
 flags‿args ← 2↑'-' ((≠⟜⊑)¨⊔⊢) 𝕩
 # TODO(sterni): support multiple flags in one argument, e.g. -si
 ⟨sort,help,inPlace⟩ ⇐ flags∊˜⟨"-s","-h","-i"⟩

 argCount ← 2
 {𝕤
   •Out "Usage: "∾•name∾" [-s] [-i] /path/to/inputrc /path/to/lib/keyboard

    -i    Modify lib/keyboard in place. If not given, print to stdout.
    -s    Sort output by Unicode Codepoint."
    •Exit ¬help
 }⍟(help∨argCount≠≠args) @

 inputrcPath‿keyboardPath ⇐ •wdpath⊸•file.At¨args
 WriteOutput ⇐ inPlace◶⟨•out¨,keyboardPath⊸•fLines⟩
} •args

# Main Program

# Read inputrc, dropping comment and empty lines. Also drop the rule for \\.
# Since Plan9 requires an explicit keypress before entering a compose sequence,
# we don't need to add a way to type \ (or any ASCII character for that matter).
# This simplifies the parser below since we don't need to unescape anything.
inputrc←1↓(("#"⊸≢⟜(1⊸↑)∧0⊸≠∘≠)¨/⊢)•FLines opts.inputrcPath
# After removing all backslashes, the ASCII character used representing the used
# key and the resulting codepoint have a consistent position in the lines.
# Remove all ASCII chars in a second step.
# map contains pairs of ⟨BQN char, key used to type it as an ASCII char⟩
map←(¬∘IsAscii∘⊑¨/⊢)5‿1⊸⊏¨'\'(≠/⊢)¨inputrc

# Render the first three fields of lib/keyboard:
# ⟨Codepoint (Hex), Compose Sequence, Resulting Character⟩
newfields←{𝕊 c‿k: ⟨4 ToHex c-@,"\"∾k,c⟩}¨map
# In the file, the fields need be padded to a specific length…
fieldsz←6‿12‿0⌈⌈´˘⍉≠¨>newfields
# … and there's a fourth name field separated by a tab.
# We don't make an effort to add a per character description there (yet).
tab←@+9
newlines←((tab∾"BQN char") ∾´fieldsz⊸(↑¨))¨ newfields

# Due to the consistent spacing we can just compute the sort order on the
# resulting character at index 18.
Sort ← (⍋ 18⊸⊑¨)⊏⊢

# Deduplicate output before writing, so the script can be executed multiple
# times or after inputrc has been changed without introducing duplicates. Since
# we duplicate on entire lines, existing alternative compose sequences aren't
# removed.
opts.WriteOutput ⍷ Sort⍟opts.sort (•FLines opts.keyboardPath)∾newlines
