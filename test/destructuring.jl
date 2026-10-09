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
