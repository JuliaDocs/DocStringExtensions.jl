module Geometry
using DocStringExtensions

"""
This docstring comes before the `@template` definitions below, so it renders as written.
"""
unit_circle() = Circle(1.0)

@template (FUNCTIONS, METHODS) = """
    $(TYPEDSIGNATURES)
    $(DOCSTRING)
    """

@template TYPES = """
    $(TYPEDEF)
    $(DOCSTRING)
    $(TYPEDFIELDS)
    """

"""
This docstring holds only this sentence. The template adds the definition above it and the
fields below it.
"""
struct Circle
    "The distance from the centre to the edge."
    radius::Float64
end

"""
This docstring holds only this sentence. The template adds the signature above it.
"""
area(c::Circle) = π * c.radius^2

module Plain
using DocStringExtensions
import ..Geometry: Circle

"""
`Plain` is a submodule of `Geometry` but defines no template of its own, so this docstring
renders as written.
"""
perimeter(c::Circle) = 2π * c.radius
end

module Copied
using DocStringExtensions
import ..Geometry
import ..Geometry: Circle

@template (FUNCTIONS, METHODS) = Geometry

"""
`Copied` copies the function template from `Geometry`, so the signature is added here too.
"""
diameter(c::Circle) = 2 * c.radius
end

end
