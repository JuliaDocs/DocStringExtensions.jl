module DestructuringTestModule

using DocStringExtensions
import DocStringExtensions: TypedMethodSignatures

"""
$(SIGNATURES)
"""
pair((a, b)) = a

"""
$(TypedMethodSignatures(false))
"""
typed((a, b)::Tuple, (c, d), e::String) = e

"""
$(SIGNATURES)
"""
nested(((a, b), c), d = 1) = d

struct Unshowable end
Base.show(io::IO, ::Unshowable) = error("`Unshowable` is never shown")

# A default that is not shown must not be rendered when the docstring is defined.
@eval begin
    """
    $(SIGNATURES)
    """
    unshowable((a, b), x = $(Unshowable())) = a
end

module Templated

using DocStringExtensions

@template METHODS =
    """
    $(SIGNATURES)

    $(DOCSTRING)
    """

"method `templated`"
templated((x, y)) = x

end

end
