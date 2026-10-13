"""
The type for [`SIGNATURES`](@ref) abbreviations.

$(:FIELDS)
"""
struct MethodSignatures <: Abbreviation
    returns::Union{Bool,String}
    defaults::Union{Bool,Symbol}
    definition::Union{DefinitionArguments,Nothing}
    type_definition::Union{StructDefinition,Nothing}
end

function check_defaults(defaults::Union{Bool,Symbol})
    defaults isa Bool || defaults === :brackets || throw(ArgumentError(
        "`defaults` must be `true`, `false`, or `:brackets`, got `$(repr(defaults))`."))
    return defaults
end

MethodSignatures(; returns::Union{Bool,String} = false, defaults::Union{Bool,Symbol} = false) =
    MethodSignatures(returns, check_defaults(defaults), nothing, nothing)

interpolation(abbr::MethodSignatures, expr::Expr) = MethodSignatures(
    abbr.returns,
    abbr.defaults,
    definition_arguments(expr, abbr.defaults !== false),
    struct_extent(expr),
)

"""
An [`Abbreviation`](@ref) that prints the signatures of the documented method, with argument
names and keywords but no types. See [`printmethod`](@ref) for the simplifications it
applies.

In the docstring of a struct, it prints the constructors that the struct definition creates.

# Examples

```jldoctest
julia> \"""
       \$(SIGNATURES)
       Compute the area of a rectangle.
       \"""
       area(width, height = width) = width * height;

julia> @doc area
  area(width)
  area(width, height)

  Compute the area of a rectangle.
```

!!! tip "Showing Default Values"
    Default values of positional and keyword arguments are omitted. To show them, use
    `\$(DocStringExtensions.MethodSignatures(defaults = true))`. The methods that Julia
    generates for positional defaults are then printed as a single signature. Pass
    `defaults = :brackets` to print that signature without the values, marking each
    optional positional argument in brackets: `area(width, [height])`.

!!! tip "Showing the Return Value"
    To follow each signature with its inferred return type, use
    `\$(DocStringExtensions.MethodSignatures(returns = true))`. To describe the return
    value yourself, pass a string: `MethodSignatures(returns = "success::Bool")` prints
    `-> success::Bool` after each signature.
"""
const SIGNATURES = MethodSignatures()

function format(abbr::MethodSignatures, buf, doc)
    local binding = doc.data[:binding]
    local func = Base.invokelatest(Docs.resolve, binding)
    local groups = signature_groups(abbr, func, doc)
    local defaults = abbr.defaults === false ? nothing : abbr.definition

    if !isempty(groups)
        local lines = String[]
        for group in groups, method in collapse_defaults(group, defaults)
            push!(lines, sprint(io -> printmethod(io, binding, func, method;
                definition = abbr.definition, returns = abbr.returns,
                brackets = abbr.defaults === :brackets)))
        end
        println(buf)
        println(buf, "```julia")
        # A struct's typed constructor and its untyped fallback print the same signature.
        foreach(line -> println(buf, line), unique(lines))
        println(buf, "```\n")
    end
end

"""
The type for [`TYPEDSIGNATURES`](@ref) abbreviations.

$(:FIELDS)
"""
struct TypedMethodSignatures <: Abbreviation
    returns::Union{Bool,String}
    defaults::Union{Bool,Symbol}
    definition::Union{DefinitionArguments,Nothing}
    type_definition::Union{StructDefinition,Nothing}
end

TypedMethodSignatures(; returns::Union{Bool,String} = true, defaults::Union{Bool,Symbol} = false) =
    TypedMethodSignatures(returns, check_defaults(defaults), nothing, nothing)

interpolation(abbr::TypedMethodSignatures, expr::Expr) = TypedMethodSignatures(
    abbr.returns,
    abbr.defaults,
    definition_arguments(expr, abbr.defaults !== false),
    struct_extent(expr),
)

"""
An [`Abbreviation`](@ref) that prints the signatures of the documented method like
[`SIGNATURES`](@ref), with the types of positional and keyword arguments and the inferred
return type. See [`printmethod`](@ref) for the simplifications it applies. In the docstring
of a struct, it prints the constructors that [`SIGNATURES`](@ref) lists.

# Examples

```jldoctest
julia> \"""
       \$(TYPEDSIGNATURES)
       Compute the area of a rectangle.
       \"""
       area(width::Int, height::Int) = width * height;

julia> @doc area
  area(width::Int64, height::Int64) -> Int64

  Compute the area of a rectangle.
```

!!! tip "Changing the Return Type"
    The return type is often inferred as `Any`. To leave it out, use
    `\$(DocStringExtensions.TypedMethodSignatures(returns = false))`. To describe the
    return value yourself, pass a string: `TypedMethodSignatures(returns = "success::Bool")`
    prints `-> success::Bool` after each signature.

!!! tip "Showing Default Values"
    Default values of positional and keyword arguments are omitted. To show them, pass
    `defaults = true`: `\$(DocStringExtensions.TypedMethodSignatures(defaults = true))`.
    The methods that Julia generates for positional defaults are then printed as a single
    signature. Pass `defaults = :brackets` to print that signature without the values,
    marking each optional positional argument in brackets.
"""
const TYPEDSIGNATURES = TypedMethodSignatures()

# The methods a signature abbreviation prints: the constructors of a documented struct, or the
# documented method's group.
function signature_groups(abbr::Union{MethodSignatures,TypedMethodSignatures}, func, doc)
    local modname = doc.data[:module]
    if abbr.type_definition !== nothing
        local constructors = struct_constructors(func, abbr.type_definition, modname)
        return isempty(constructors) ? Vector{Method}[] : [constructors]
    end
    return documented_groups(methodgroups(func, doc.data[:typesig], modname), doc)
end

"""
$(:SIGNATURES)

Drop the methods of `group` that Julia generated for positional default values, keeping
the method that takes every argument of `definition`.
"""
collapse_defaults(group, ::Nothing) = group
function collapse_defaults(group, definition::DefinitionArguments)
    local matching = filter(m -> matches_definition(m, definition), group)
    isempty(matching) && return group
    local longest = maximum(m -> length(arguments(m)), matching)
    return filter(group) do m
        !matches_definition(m, definition) || length(arguments(m)) == longest
    end
end

function format(tms::TypedMethodSignatures, buf, doc)
    local binding = doc.data[:binding]
    local typesig = doc.data[:typesig]
    local func = Base.invokelatest(Docs.resolve, binding)
    local groups = signature_groups(tms, func, doc)
    local defaults = tms.defaults === false ? nothing : tms.definition
    if !isempty(groups)
        group = groups[end]
        println(buf)
        println(buf, "```julia")
        for method in collapse_defaults(group, defaults)
            N = length(arguments(method))
            # return a list of tuples that represent type signatures
            tuples = find_tuples(typesig)
            # Without a tuple equal to the method's signature, take one with as many arguments.
            function f(t)
                if t isa DataType
                    return t <: Tuple && length(t.types) == N
                elseif t isa UnionAll
                    return f(t.body)
                else
                    return false
                end
            end

            idx = findfirst(t -> t == argsig(method), tuples)
            if idx === nothing
                @static if Sys.iswindows() && VERSION < v"1.8"
                    idx = findlast(f, tuples)
                else
                    idx = findfirst(f, tuples)
                end
            end
            # Julia 1.12 and later can normalise `typesig` to `Tuple`, leaving no tuple of length `N`.
            # An expanded vararg has no tuple of length `N` either, and can match a wrong one.
            # A parametric constructor's name needs the type parameters of its own signature.
            t = idx === nothing || expanded_vararg(method) || constructor_parameters(method) !== nothing ?
                argsig(method) : tuples[idx]
            printmethod(buf, binding, func, method, t;
                returns = tms.returns, definition = tms.definition,
                brackets = tms.defaults === :brackets)
            println(buf)
        end
        println(buf, "```\n")
    end
end
