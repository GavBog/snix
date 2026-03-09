//! This module encapsulates some logic for upvalue handling, which is
//! relevant to both thunks (delayed computations for lazy-evaluation)
//! as well as closures (lambdas that capture variables from the
//! surrounding scope).
//!
//! The upvalues of a scope are whatever data are needed at runtime
//! in order to resolve each free variable in the scope to a value.
//! "Upvalue" is a term taken from Lua.

use std::ops::Index;

use crate::{Value, opcode::UpvalueIdx};

/// Structure for carrying upvalues of an UpvalueCarrier.  The
/// implementation of this struct encapsulates the logic for
/// capturing and accessing upvalues.
///
/// Nix's `with` cannot be used to shadow an enclosing binding --
/// like Rust's `use xyz::*` construct, but unlike Javascript's
/// `with (xyz)`.  This means that Nix has two kinds of identifiers,
/// which can be distinguished at compile time:
///
/// - Static identifiers, which are bound in some enclosing scope by
///   `let`, `name:` or `{name}:`
/// - Dynamic identifiers, which are not bound in any enclosing
///   scope
#[derive(Clone, Debug)]
pub struct Upvalues {
    /// The upvalues of static identifiers.  Each static identifier
    /// is assigned an integer identifier at compile time, which is
    /// an index into this Vec.
    static_upvalues: Vec<Value>,

    /// The upvalues of dynamic identifiers, if any exist.  This
    /// consists of the value passed to each enclosing `with val;`,
    /// from outermost to innermost.
    with_stack: Vec<Value>,
}

impl Upvalues {
    pub fn with_capacity(count: usize) -> Self {
        Upvalues {
            static_upvalues: Vec::with_capacity(count),
            with_stack: vec![],
        }
    }

    /// Construct an [Upvalues] instance from the raw static and with stacks.
    pub fn from_raw_parts(static_upvalues: Vec<Value>, with_stack: Vec<Value>) -> Self {
        Self {
            static_upvalues,
            with_stack,
        }
    }

    /// Get the number of static upvalues
    pub fn len(&self) -> usize {
        self.static_upvalues.len()
    }

    /// Retrieve a single value from the `with_stack`. Returns `None`
    /// if the stack doesn't exist or the value isn't in range.
    pub fn get_from_with_stack(&self, index: usize) -> Option<Value> {
        self.with_stack.get(index).cloned()
    }

    pub fn with_stack(&self) -> &Vec<Value> {
        self.with_stack.as_ref()
    }

    pub fn with_stack_len(&self) -> usize {
        self.with_stack.len()
    }

    pub fn into_static_upvalues(self) -> Vec<Value> {
        self.static_upvalues
    }

    /// Resolve deferred upvalues from the provided stack slice,
    /// mutating them in the internal upvalue slots.
    pub fn resolve_deferred_upvalues(&mut self, stack: &[Value]) {
        for upvalue in self.static_upvalues.iter_mut() {
            if let Value::DeferredUpvalue(update_from_idx) = upvalue {
                *upvalue = stack[update_from_idx.0].clone();
            }
        }
    }
}

impl Index<UpvalueIdx> for Upvalues {
    type Output = Value;

    fn index(&self, index: UpvalueIdx) -> &Self::Output {
        &self.static_upvalues[index.0]
    }
}
