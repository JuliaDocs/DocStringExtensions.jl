module DefaultsTestModule

using DocStringExtensions
import DocStringExtensions: MethodSignatures, TypedMethodSignatures

"""
$(MethodSignatures(defaults = true))
"""
positional(x, y = 1, z = "z"; kwargs...) = x

"""
$(MethodSignatures(defaults = true))
"""
keywords(x; a = :a, b::Float64 = 2.0, c, d...) = x

"""
$(TypedMethodSignatures(false; defaults = true))
"""
typed(x::Float64, y::Float64 = 2.0; z = nothing) = x

"""
$(TypedMethodSignatures(false; defaults = true))
"""
parametric(x::T, y::T = zero(T)) where {T <: Real} = x

"""
$(TypedMethodSignatures(false; defaults = true))
"""
unnamed(::String, ::Float64 = 0.0) = nothing

"""
$(MethodSignatures(defaults = true))
"""
@inline wrapped(x, y = nothing) = x

"""
$(MethodSignatures(defaults = true))
"""
nospecialized(@nospecialize(x), y = 1) = y

"""
$(MethodSignatures(defaults = true))
"""
destructured((a, b), c = 1) = c

"""
$(MethodSignatures(defaults = true))
"""
varargs(x = 1, xs...) = x

module Templated

using DocStringExtensions
import DocStringExtensions: MethodSignatures

@template METHODS =
    """
    $(MethodSignatures(defaults = true))

    $(DOCSTRING)
    """

"method `templated`"
templated(x, y = 1) = x

end

end
