#!/usr/bin/env BQN

⟨WithFlipdot⟩ ⇐ •Import "../lib/"⊸∾⍟("bin" (⊣≡(-∘≠⊸↑)) •path) "blipqn.bqn"

examples ← ⍉>⟨
"random"‿{𝕩.Send 𝕩.shape •rand.Range 2},
"235"‿{𝕩.Send 1˙⌾(4‿22⊸⊑) 𝕩.empty},
⟩

usage ← "Usage: "∾•name∾" HOST PORT WIDTH HEIGHT EXAMPLE"∾"

       where EXAMPLE is one of

"∾∾{(7↑"")∾"- "∾𝕩∾@+10}¨⊏examples

# TODO(sterni): this is an atrocious interface
opts ← {
  (•Exit 1˙∘•Out)⍟(5⊸≠≠•args) usage
  host‿port‿width‿height‿example ← •args

  example ⇐
  cfg ⇐ ⟨host⟩∾•ParseFloat¨ port‿width‿height
}

action ← examples (⊏⊸(⊑∘⊐) ⊑ ⊏˜⟜1)⟜< opts.example

opts.cfg WithFlipdot action
