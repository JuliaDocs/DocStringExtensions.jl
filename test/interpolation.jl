module InterpolationTestModule

struct TestType
    value::Int
end

import DocStringExtensions

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
