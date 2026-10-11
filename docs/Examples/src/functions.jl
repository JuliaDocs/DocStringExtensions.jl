"""
`foo` is declared with `function foo end`, so this docstring belongs to the function, not
to one method. [`METHODLIST`](@ref) lists its methods with links to their source:

$(METHODLIST)

---

[`TYPEDMETHODLIST`](@ref) lists the same methods with argument and return types:

$(TYPEDMETHODLIST)
"""
function foo end

"""
This method has a default value for `y`, so Julia defines two methods, `foo(x::Int)` and
`foo(x::Int, y::Int)`. [`SIGNATURES`](@ref) prints both:

$(SIGNATURES)

---

[`TYPEDSIGNATURES`](@ref) adds the argument types and the inferred return type:

$(TYPEDSIGNATURES)

---

Passing `defaults = true` to [`MethodSignatures`](@ref DocStringExtensions.MethodSignatures)
or [`TypedMethodSignatures`](@ref DocStringExtensions.TypedMethodSignatures) shows the
default value and prints the two methods as one signature:

$(DocStringExtensions.TypedMethodSignatures(true; defaults = true))

---

[`FUNCTIONNAME`](@ref) prints the function's name, here $(FUNCTIONNAME), for use in a
signature written by hand:

    $(FUNCTIONNAME)(x, ...)
"""
foo(x::Int, y::Int=3) = x + y

"""
A second method of [`$(FUNCTIONNAME)`](@ref). [`SIGNATURES`](@ref):

$(SIGNATURES)

[`TYPEDSIGNATURES`](@ref):

$(TYPEDSIGNATURES)
"""
foo(x::String) = length(x)
