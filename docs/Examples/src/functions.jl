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

$(DocStringExtensions.TypedMethodSignatures(defaults = true))

---

Passing `defaults = :brackets` prints one signature without the default value, with the
optional argument in brackets:

$(DocStringExtensions.MethodSignatures(defaults = :brackets))

---

Passing a string as `returns` describes the return value in place of the inferred type:

$(DocStringExtensions.MethodSignatures(returns = "sum::Int"))

---

[`FUNCTIONNAME`](@ref) prints the function's name, here $(FUNCTIONNAME), for use in a
signature written by hand:

    $(FUNCTIONNAME)(x, ...)
"""
foo(x::Int, y::Int = 3) = x + y

"""
A second method of [`$(FUNCTIONNAME)`](@ref). [`SIGNATURES`](@ref):

$(SIGNATURES)

[`TYPEDSIGNATURES`](@ref) also prints the type of the keyword argument `pad`:

$(TYPEDSIGNATURES)

[`BODY`](@ref) prints the method's body:

$(BODY)
"""
foo(x::String; pad::Int = 0) = length(x) + pad
