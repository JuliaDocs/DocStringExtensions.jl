module BodyTestModule

using DocStringExtensions

"""
$(BODY)
"""
logit(p) = log(p / (1 - p))

"""
$(BODY)
"""
function clamped(x::T, lo::T, hi::T) where {T <: Real}
    # A comment the parser drops.
    if x < lo
        return lo
    end
    return min(x, hi)
end

"""
$(BODY)
"""
function nested(xs)
    for (i, x) in enumerate(xs), j in 1:i
        if x > 0
            @info "positive" x
        else
            continue
        end
    end
    try
        open("data.txt") do io
            read(io, String)
        end
    catch err
        err isa SystemError || rethrow()
    end
    return [x^2 for x in xs if x > 0]
end

"""
$(BODY)
"""
quoted(x) = :(x + $(x))

"""
$(BODY)
"""
@inline wrapped(x) = 2x

"""
$(BODY)
"""
function emptybody(x)
end

"""
$(BODY)
"""
function nomethods end

"""
$(BODY)
"""
struct NotAMethod end

module Templated

using DocStringExtensions

@template METHODS =
    """
    $(BODY)

    $(DOCSTRING)
    """

"method `templated`"
templated(x) = x + 1

end

end
