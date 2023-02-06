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

end
