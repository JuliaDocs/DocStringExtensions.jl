"""
The type for [`SIGNATURES`](@ref) abbreviations.

$(:FIELDS)
"""
struct MethodSignatures <: Abbreviation
    returns::Union{Bool, String}
    defaults::Union{Bool, Symbol}
    definition::Union{DefinitionArguments, Nothing}
    type_definition::Union{StructDefinition, Nothing}
end

function check_defaults(defaults::Union{Bool, Symbol})
    defaults isa Bool || defaults === :brackets || throw(
        ArgumentError(
            "`defaults` must be `true`, `false`, or `:brackets`, got `$(repr(defaults))`."
        )
    )
    return defaults
end

MethodSignatures(; returns::Union{Bool, String} = false, defaults::Union{Bool, Symbol} = false) =
    MethodSignatures(returns, check_defaults(defaults), nothing, nothing)

"""
An [`Abbreviation`](@ref) that prints the signatures of the documented method, with argument
names and keywords but no types or default values. An unnamed argument prints as `::T` when
it declares a type `T`, and as `_` otherwise. A destructured argument prints as written, such
as `(a, b)`.

In the docstring of a struct, it prints the constructors that the struct definition creates.
A callable method of a type's instances, such as `(e::E)(x)`, prints as it is defined.
In the docstring of a macro, it prints the macro as its caller writes it, such as `@m a b`,
without the `__source__` and `__module__` arguments.

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
    `-> success::Bool` after each signature. A reader can change the arrow with a
    [rendering setting](@ref setup-rendering).
"""
const SIGNATURES = MethodSignatures()

function format(abbr::MethodSignatures, buf, doc)
    binding = doc_binding(doc)
    func = Base.invokelatest(Docs.resolve, binding)
    groups = signature_groups(abbr, func, doc)
    defaults = abbr.defaults === false ? nothing : abbr.definition

    return if !isempty(groups)
        lines = String[]
        for group in groups, method in collapse_defaults(group, defaults)
            push!(
                lines, sprint(
                    io -> printmethod(
                        io, binding, func, method;
                        definition = abbr.definition, returns = abbr.returns,
                        brackets = abbr.defaults === :brackets
                    )
                )
            )
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
    returns::Union{Bool, String}
    defaults::Union{Bool, Symbol}
    definition::Union{DefinitionArguments, Nothing}
    type_definition::Union{StructDefinition, Nothing}
end

TypedMethodSignatures(; returns::Union{Bool, String} = true, defaults::Union{Bool, Symbol} = false) =
    TypedMethodSignatures(returns, check_defaults(defaults), nothing, nothing)

interpolation(abbr::T, expr::Expr) where {T <: Union{MethodSignatures, TypedMethodSignatures}} = T(
    abbr.returns,
    abbr.defaults,
    definition_arguments(expr, abbr.defaults !== false),
    struct_extent(expr),
)

"""
An [`Abbreviation`](@ref) that prints the signatures of the documented method like
[`SIGNATURES`](@ref), with the types of positional and keyword arguments and the inferred
return type. Type parameters keep their names, declared in a `where` clause after the
arguments, and default values are left out as in [`SIGNATURES`](@ref). In the docstring
of a struct, it prints the constructors that [`SIGNATURES`](@ref) lists. A callable such as
`(e::E)(x::Int)` prints as `(e::Main.E)(x::Int64)` when `E` is defined in `Main`. Before
Julia 1.6, a callable and a constructor written `T{P}(...)` print without a return type. A macro
prints as [`SIGNATURES`](@ref) prints it, with argument types such as `@m ex::Expr` and no
inferred return type. An inferred return type that Julia would print with a name it generated,
as for a parameter written `<:T` that no `const` alias gives, is left out.

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
    A return type inferred as `Any` is left out. To leave out every return type, use
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
function signature_groups(abbr::Union{MethodSignatures, TypedMethodSignatures}, func, doc)
    modname = doc_module(doc)
    if abbr.type_definition !== nothing
        constructors = struct_constructors(func, abbr.type_definition, modname)
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
    matching = filter(m -> matches_definition(m, definition), group)
    isempty(matching) && return group
    longest = maximum(m -> length(arguments(m)), matching)
    return filter(group) do m
        !matches_definition(m, definition) || length(arguments(m)) == longest
    end
end

function format(tms::TypedMethodSignatures, buf, doc)
    binding = doc_binding(doc)
    typesig = doc.data[:typesig]
    func = Base.invokelatest(Docs.resolve, binding)
    groups = signature_groups(tms, func, doc)
    defaults = tms.defaults === false ? nothing : tms.definition
    return if !isempty(groups)
        group = groups[end]
        tuples = alltypesigs(typesig)
        println(buf)
        println(buf, "```julia")
        for method in collapse_defaults(group, defaults)
            printmethod(
                buf, binding, func, method, printed_typesig(func, method, tuples);
                returns = tms.returns, definition = tms.definition,
                brackets = tms.defaults === :brackets
            )
            println(buf)
        end
        println(buf, "```\n")
    end
end

# The signature `TYPEDSIGNATURES` prints for `method`: the tuple of `tuples` equal to the
# method's signature, or else one with as many arguments.
function printed_typesig(func, method::Method, tuples)
    sig = argsig(method)
    # An expanded vararg has no tuple with as many arguments, and can match a wrong one.
    # A parametric constructor's name and a callable's instance type need the type parameters
    # of the method's own signature.
    (
        expanded_vararg(method) || constructor_parameters(func, method) !== nothing ||
            instance_type(func, method) !== nothing
    ) && return sig
    idx = findfirst(t -> t == sig, tuples)
    if idx === nothing
        n = length(arguments(method))
        @static if Sys.iswindows() && VERSION < v"1.8"
            idx = findlast(t -> has_arity(t, n), tuples)
        else
            idx = findfirst(t -> has_arity(t, n), tuples)
        end
    end
    # Julia 1.12 and later can normalise `typesig` to `Tuple`, leaving no tuple of length `n`.
    return idx === nothing ? sig : tuples[idx]
end

has_arity(t::UnionAll, n) = has_arity(t.body, n)
has_arity(t, n) = t <: Tuple && length(t.types) == n
