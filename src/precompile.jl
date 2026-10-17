# Representative docstrings expanded during precompilation
module _PrecompileWorkload

    using ..DocStringExtensions

    const PtrOrRef{T} = Union{Ptr{T}, Ref{T}}

    """
    $(TYPEDEF)

    $(TYPEDFIELDS)
    """
    struct Point{T <: Real}
        "x"
        x::T
        "y"
        y::T
    end

    """
    $(TYPEDSIGNATURES)
    """
    point(x::T, y::T = zero(T)) where {T <: Real} = Point(x, y)

    """
    $(TYPEDSIGNATURES)
    """
    scale(p::Point, s::Union{Integer, AbstractFloat} = 1; round::Bool = false) = p

    """
    $(TYPEDSIGNATURES)
    """
    fill!(out::PtrOrRef{Point{Float64}}, xs::Vector{Float64}, n::Integer...) = nothing

    """
    $(SIGNATURES)

    $(METHODLIST)
    """
    untyped(a, b = 1; c = 2) = a

    """
    $(FUNCTIONNAME)

    $(FIELDS)
    """
    mutable struct Mutable
        a::Int
    end

end

@setup_workload begin
    docstrs = [docstr for multidoc in values(Docs.meta(_PrecompileWorkload)) for docstr in values(multidoc.docs)]
    @compile_workload begin
        # `Docs.parsedoc` is defined by the REPL stdlib, so expand the abbreviations directly.
        buf = IOBuffer()
        for docstr in docstrs
            for part in docstr.text
                if part isa Abbreviation
                    format(part, buf, docstr)
                end
            end
        end
    end
end
