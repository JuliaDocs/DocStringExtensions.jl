module MacrosTestModule

using DocStringExtensions
# Inferred return types differ between Julia versions.
import DocStringExtensions: MethodSignatures, TypedMethodSignatures

"""
$(SIGNATURES)
$(TypedMethodSignatures(returns = false))
vararg `@vararg`
"""
macro vararg(xs...)
    return nothing
end

"""
$(SIGNATURES)
$(TypedMethodSignatures(returns = false))
two arguments `@pair`
"""
macro pair(a, b)
    return nothing
end

"""
$(SIGNATURES)
$(TypedMethodSignatures(returns = false))
one argument `@two`
"""
macro two(a)
    return nothing
end

"""
$(SIGNATURES)
$(TypedMethodSignatures(returns = false))
two arguments `@two`
"""
macro two(a, b)
    return nothing
end

"""
$(SIGNATURES)
$(TypedMethodSignatures(returns = false))
typed `@typed`
"""
macro typed(ex::Expr, s::Symbol)
    return nothing
end

"""
$(SIGNATURES)
$(TypedMethodSignatures(returns = false))
$(MethodSignatures(defaults = true))
$(MethodSignatures(defaults = :brackets))
$(TypedMethodSignatures(returns = false, defaults = true))
default `@default`
"""
macro default(a, b = 1)
    return nothing
end

"""
$(SIGNATURES)
$(TypedMethodSignatures(returns = false))
$(MethodSignatures(defaults = true))
$(TypedMethodSignatures(returns = false, defaults = true))
$(TypedMethodSignatures(returns = false, defaults = :brackets))
typed default `@typeddefault`
"""
macro typeddefault(a::Symbol, b::Integer = 1)
    return nothing
end

"""
$(SIGNATURES)
$(TypedMethodSignatures(returns = false))
typed vararg `@typedvararg`
"""
macro typedvararg(ex::Expr, xs::Symbol...)
    return nothing
end

"""
$(SIGNATURES)
$(TypedMethodSignatures(returns = false))
destructured `@destructured`
"""
macro destructured((a, b), c)
    return nothing
end

"""
$(MethodSignatures(returns = true))
$(TypedMethodSignatures())
$(MethodSignatures(returns = "Expr"))
$(TypedMethodSignatures(returns = "Expr"))
returns `@returns`
"""
macro returns(xs...)
    return Expr(:block)
end

"""
$(SIGNATURES)
$(TypedMethodSignatures(returns = false))
no arguments `@none`
"""
macro none()
    return nothing
end

"""
$(SIGNATURES)
$(TypedMethodSignatures(returns = false))
long `@long`
"""
macro long(first_argument_name::Expr, second_argument_name::Symbol, third_argument_name::Expr)
    return nothing
end

"""
$(METHODLIST)
$(TYPEDMETHODLIST)
listed `@listed`
"""
macro listed(ex::Expr, xs...)
    return Expr(:block)
end

# A function named with a leading `@` is not a macro. Julia 1.0 cannot parse `var"@notmacro"`.
@eval @doc """
$(SIGNATURES)
$(TypedMethodSignatures(returns = false))
function `@notmacro`
""" $(Symbol("@notmacro"))(a, b, c) = a

end
