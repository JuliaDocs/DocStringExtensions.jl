module InterpolationTestModule

struct TestType
    value::Int
end

import DocStringExtensions

# For TestType(1), it interpolates the function signature, and for
# TestType(2) it interpolates the function body.
DocStringExtensions.interpolation(obj::TestType, ex::Expr) = ex.args[obj.value]

"""
$(TestType(1))
"""
f(x) = x + 1

"""
$(TestType(2))
"""
g(x) = x + 2

module Templated

using DocStringExtensions
import ..TestType

@template METHODS =
    """
    $(TestType(1))

    $(DOCSTRING)
    """

"method `h`"
h(x) = x + 3

end

struct StructOnly end

DocStringExtensions.interpolation(::StructOnly, ex::Expr) =
    Meta.isexpr(ex, :struct) ? "struct" : error("`StructOnly` only documents structs")

module StructOnlyTemplate

using DocStringExtensions
import ..StructOnly

# Deciding whether to keep `expr` must not call `interpolation` on another category's parts.
@template TYPES =
    """
    $(StructOnly())

    $(DOCSTRING)
    """

"method `k`"
k(x) = x

end

end
