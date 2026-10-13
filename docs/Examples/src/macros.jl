"""
Repeat `ex` a number of times. [`SIGNATURES`](@ref) prints the macro as its caller writes
it, without the `__source__` and `__module__` arguments every macro receives:

$(SIGNATURES)

---

[`TYPEDSIGNATURES`](@ref) adds the argument types, and no return type:

$(TYPEDSIGNATURES)

---

Passing `defaults = true` shows the default value in one signature:

$(DocStringExtensions.MethodSignatures(defaults = true))
"""
macro repeat(ex::Expr, n = 2)
    return Expr(:block, fill(ex, n)...)
end
