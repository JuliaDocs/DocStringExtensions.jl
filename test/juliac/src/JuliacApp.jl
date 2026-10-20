"""
A package that `juliac --trim=safe` compiles to check that depending on
DocStringExtensions keeps a package trimmable.
"""
module JuliacApp

using DocStringExtensions
using Markdown
using REPL

export Point, shift

@template DEFAULT = """
$(TYPEDSIGNATURES)
$(DOCSTRING)
"""

@template TYPES = """
$(TYPEDEF)
$(DOCSTRING)
$(TYPEDFIELDS)
"""

"A point on the integer grid."
struct Point
    "Horizontal position."
    x::Int
    "Vertical position."
    y::Int
end

"$(FUNCTIONNAME) moves `p` by `dx` and `dy`."
shift(p::Point, dx::Int, dy::Int = 0) = Point(p.x + dx, p.y + dy)

"""
$(SIGNATURES)

Taxicab distance of `p` from the origin.
"""
norm1(p::Point) = abs(p.x) + abs(p.y)

# Trimming strips docstrings from the binary, so they are rendered while the package builds.
const DOCS = join((string(@doc(Point)), string(@doc(shift)), string(@doc(norm1))), "\n")

function (@main)(args::Vector{String})::Cint
    println(Core.stdout, norm1(shift(Point(1, 2), 3, 4)))
    println(Core.stdout, DOCS)
    return 0
end

end
