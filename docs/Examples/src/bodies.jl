"""
The values that appear more than once in `xs`. [`BODY`](@ref) prints the method's body,
with nested blocks and a macro call:

$(BODY)
"""
function duplicates(xs)
    counts = Dict{eltype(xs),Int}()
    for x in xs
        if haskey(counts, x)
            counts[x] += 1
        else
            @debug "first sighting" x
            counts[x] = 1
        end
    end
    return [k for (k, n) in counts if n > 1]
end
