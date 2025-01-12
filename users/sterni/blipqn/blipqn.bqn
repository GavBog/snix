MakeFlipdot⇐

# - host (char*) argument:
#   - Assume char is i8 (safe even if it's actually u8 if
#     ASCII). We can't let •FFI check this for us since CBQN doesn't support
#     specifying c7. We do this in MakeFlipdot
#   - Needs to be zero-terminated, we also do this in MakeFlipdot.
# - bitmap_len (size_t) argument: assume size_t is at least u32.
ffi_send_to_flipdot ← "libflipdot.so" •FFI "i8"‿"send_to_flipdot"‿"*i8:c8"‿"u16"‿"*u8"‿"u32"

Compact ← +´∘(⌽ × 2⊸⋆∘↕∘≠)˘∘(∘‿8⊸⥊)

MakeFlipdot ← {
  host‿port 𝕊 w‿h:
  "Total pixel count must be divisible by 8" ! 0=8|w×h
  "Hostname must be ASCII"                   ! ∧´(@+127)≥host
  shape ⇐ h‿w
  empty ⇐ shape⥊0
  Send ⇐ {"sendto(2) error"!FFI_send_to_flipdot (host∾@)‿port∾(⊢⋈≠) Compact 𝕩}
}
