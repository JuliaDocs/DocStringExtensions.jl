module FieldDefaultsTestModule

using DocStringExtensions
import DocStringExtensions: TypeFields

"""
$(FIELDS)
"""
Base.@kwdef struct Options
    "Number of retries."
    retries::Int = 3
    name::String
    scale = retries + 1
end

"""
$(TYPEDFIELDS)
"""
Base.@kwdef mutable struct Settings
    level::Float64 = 1.0
    "Shown in the title bar."
    label::String = "default"
end

"""
$(FIELDS)
"""
Base.@kwdef struct Verbatim
    "Shown on start."
    greeting::String = "run `make`"
    total::Float64 = begin
        1.0 + 2.0
    end
end

"""
$(TypeFields(false; defaults = false))
"""
Base.@kwdef struct Hidden
    a::Int = 1
end

"""
$(FIELDS)
"""
struct Plain
    a::Int
end

module Templated

using DocStringExtensions

@template TYPES =
    """
    $(TYPEDFIELDS)

    $(DOCSTRING)
    """

"type `Config`"
Base.@kwdef struct Config
    a::Float64 = 1.0
end

end

end
