# Rendering settings that a reader picks in their own environment. They apply to the docstrings
# of every package alike, and are read each time a docstring renders.

"""
$(:SIGNATURES)

The arrow between a signature and its return type: the value of
`DOCSTRINGEXTENSIONS_RETURN_ARROW`, such as `→`, or `->` when it is unset or empty.
"""
function return_arrow()
    arrow = get(ENV, "DOCSTRINGEXTENSIONS_RETURN_ARROW", "")
    return isempty(arrow) ? "->" : arrow
end

"""
$(:SIGNATURES)

The longest signature, in characters, that prints on one line: the value of
`DOCSTRINGEXTENSIONS_SIGNATURE_WIDTH`, or 60 when it is unset or empty. A longer signature
prints one argument per line. A value that is not a positive integer warns and gives 60.
"""
function signature_width()
    value = get(ENV, "DOCSTRINGEXTENSIONS_SIGNATURE_WIDTH", "")
    isempty(value) && return 60
    width = tryparse(Int, value)
    width !== nothing && width > 0 && return width
    @warn "`DOCSTRINGEXTENSIONS_SIGNATURE_WIDTH` must be a positive integer, got $(repr(value)). Using 60." maxlog = 1
    return 60
end
