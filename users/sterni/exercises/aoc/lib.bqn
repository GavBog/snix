IsAsciiNum ⇐ ('0'⊸≤∧≤⟜'9')
IsAlpha ⇐ (('a'⊸≤∧≤⟜'z')∨('A'⊸≤∧≤⟜'Z'))

# based on leah2's function
ReadInt ⇐ {
  𝕨 𝕊 𝕩: '-'=⊑𝕩? -𝕨 𝕊 1↓𝕩;
  𝕨 𝕊 𝕩: (𝕨⊸×+⊣)´∘⌽-⟜'0'𝕩
}
ReadDec ⇐ 10⊸ReadInt

SplitOn ⇐ ((⊢ (-1˙)⍟⊣¨ +`∘(1⊸»<⊢))∘(≡¨)⊔⊢)
SplitAt ← ((⊣≤↕∘≠∘⊢)⊔⊢)

_fix ⇐ {𝕩 𝕊∘⊢⍟≢ 𝔽 𝕩}

ImportBqnLibs ⇐ {•Import 𝕩∾˜"/"∾˜¯1↓1⊑•SH "printenv"‿"BQNLIBS"}

Xor ⇐ (¬⊸∧∨∧⟜¬)

# To get all Diagonals (⊢∾○Diagonals⌽)
Diagonals ⇐ {(0‿0⊸⍉ ↓⟜𝕩)¨ (↕≠𝕩)}

ApplyMany ← {fs 𝕊 arg: {𝕏 arg}¨ fs}
