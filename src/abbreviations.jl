
#
# Abstract Interface.
#

"""
Abbreviation objects are used to automatically generate context-dependent markdown content
within documentation strings. Objects of this type interpolated into docstrings will be
expanded automatically before parsing the text to markdown.

$(:FIELDS)
"""
abstract type Abbreviation end

"""
$(:SIGNATURES)

Expand the [`Abbreviation`](@ref) `abbr` in the context of the `DocStr` `doc` and write
the resulting markdown-formatted text to the `IOBuffer` `buf`.
"""
format(abbr, buf, doc) = error("`format` not implemented for `$(typeof(abbr))`.")

# Only extend `formatdoc` once with our abstract type. Within the package use a different
# `format` function instead to keep things decoupled from `Base` as much as possible.
Docs.formatdoc(buf::IOBuffer, doc::Docs.DocStr, part::Abbreviation) = format(part, buf, doc)


#
# Implementations.
#


#
# `TypeFields`
#

"""
The type for [`FIELDS`](@ref) abbreviations.

$(:FIELDS)
"""
struct TypeFields <: Abbreviation
    types::Bool
end

"""
An [`Abbreviation`](@ref) that lists the fields of a type, with the docstring of each field
that has one.

# Examples

```jldoctest
julia> \"""
       A point in the plane.
       \$(FIELDS)
       \"""
       struct Point
           "Horizontal coordinate."
           x::Float64
           "Vertical coordinate."
           y::Float64
           label::String
       end

julia> @doc Point
  A point in the plane.

    •  x: Horizontal coordinate.

    •  y: Vertical coordinate.

    •  label
```
"""
const FIELDS = TypeFields(false)

"""
An [`Abbreviation`](@ref) that lists the fields of a type like [`FIELDS`](@ref), with the
type of each field.

# Examples

```jldoctest
julia> \"""
       A point in the plane.
       \$(TYPEDFIELDS)
       \"""
       struct Point
           "Horizontal coordinate."
           x::Float64
           "Vertical coordinate."
           y::Float64
           label::String
       end

julia> @doc Point
  A point in the plane.

    •  x::Float64: Horizontal coordinate.

    •  y::Float64: Vertical coordinate.

    •  label::String
```
"""
const TYPEDFIELDS = TypeFields(true)

function format(abbrv::TypeFields, buf, doc)
    local docs = get(doc.data, :fields, Dict())
    local binding = doc.data[:binding]
    local object = Base.invokelatest(Docs.resolve, binding)
    local fields = isabstracttype(object) ? Symbol[] : fieldnames(object)
    if !isempty(fields)
        println(buf)
        for field in fields
            print(buf, "  - `", field)
            abbrv.types && print(buf, "::", fieldtype(object, field))
            print(buf, "`")
            # Print the field docs if they exist and aren't a `doc"..."` docstring.
            if haskey(docs, field) && isa(docs[field], AbstractString)
                print(buf, ": ")
                indented = true
                for line in split(docs[field], "\n")
                    println(buf, indented || isempty(line) ? "" : "    ", rstrip(line))
                    indented = false
                end
            else
                println(buf)
            end
            println(buf)
        end
        println(buf)
    end
    return nothing
end


#
# `ModuleExports`
#

"""
The singleton type for [`EXPORTS`](@ref) abbreviations.

$(:FIELDS)
"""
struct ModuleExports <: Abbreviation end

"""
An [`Abbreviation`](@ref) that lists the exported names of a module as Documenter.jl
`@ref` links.

# Examples

```jldoctest
julia> \"""
       Shapes and their areas.
       \$(EXPORTS)
       \"""
       module Shapes
       using DocStringExtensions
       export Circle, area
       struct Circle end
       area(::Circle) = π
       end;

julia> @doc Shapes
  Shapes and their areas.

    •  Circle
    •  area
```

!!! note

    The names are sorted alphabetically, ignoring a leading `@`, so macros sort in with the
    other names.
"""
const EXPORTS = ModuleExports()

function format(::ModuleExports, buf, doc)
    local object = Base.invokelatest(Docs.resolve, doc.data[:binding])
    # `names` also returns `public` names on Julia 1.11 and later.
    print_name_list(buf, object, filter(sym -> Base.isexported(object, sym), names(object)))
end

function print_name_list(buf, object::Module, syms)
    if !isempty(syms)
        println(buf)
        # Sorting ignores the `@` in macro names and sorts them in with others.
        for sym in sort(syms, by = s -> lstrip(string(s), '@'))
            # Skip the module itself, since that's always exported.
            sym === nameof(object) && continue
            # We print linked names using Documenter.jl cross-reference syntax
            # for ease of integration with that package.
            println(buf, "  - [`", sym, "`](@ref)")
        end
        println(buf)
    end
    return nothing
end


#
# `ModulePublic`
#

"""
The singleton type for [`PUBLIC`](@ref) abbreviations.

$(:FIELDS)
"""
struct ModulePublic <: Abbreviation end

"""
An [`Abbreviation`](@ref) that lists the public names of a module, exported or declared
`public`, as Documenter.jl `@ref` links. Before Julia 1.11, which added `public`, it lists
the exported names.

# Examples

```jldoctest
julia> \"""
       Shapes and their areas.
       \$(PUBLIC)
       \"""
       module Shapes
       using DocStringExtensions
       export Circle, area
       public perimeter
       struct Circle end
       area(::Circle) = π
       perimeter(::Circle) = 2π
       end;

julia> @doc Shapes
  Shapes and their areas.

    •  Circle
    •  area
    •  perimeter
```

!!! note

    The names are sorted alphabetically, ignoring a leading `@`, so macros sort in with the
    other names.
"""
const PUBLIC = ModulePublic()

function format(::ModulePublic, buf, doc)
    local object = Base.invokelatest(Docs.resolve, doc.data[:binding])
    print_name_list(buf, object, names(object))
end


#
# `ModuleImports`
#

"""
The singleton type for [`IMPORTS`](@ref) abbreviations.

$(:FIELDS)
"""
struct ModuleImports <: Abbreviation end

"""
An [`Abbreviation`](@ref) that lists, sorted by name, the modules a module loads with
`using`. The list includes `Base`, which every module uses implicitly.

# Examples

```jldoctest
julia> \"""
       Plotting helpers.
       \$(IMPORTS)
       \"""
       module Plots
       using DocStringExtensions, Markdown
       end;

julia> @doc Plots
  Plotting helpers.

    •  Base
    •  DocStringExtensions
    •  Markdown
```
"""
const IMPORTS = ModuleImports()

function format(::ModuleImports, buf, doc)
    local binding = doc.data[:binding]
    local object = Base.invokelatest(Docs.resolve, binding)
    local imports = unique(ccall(:jl_module_usings, Any, (Any,), object))
    if !isempty(imports)
        println(buf)
        for mod in sort(imports, by = string)
            println(buf, "  - `", mod, "`")
        end
        println(buf)
    end
end


#
# `MethodList`
#

"""
The singleton type for [`METHODLIST`](@ref) abbreviations.

$(:FIELDS)
"""
struct MethodList <: Abbreviation end

"""
An [`Abbreviation`](@ref) that lists the methods of the documented function or type that
are defined in the current module. Each method shows its signature and a link to the line
that defines it.

# Examples

Methods defined in the REPL have no file to link to, so the list below shows only their
signatures.

```jldoctest
julia> \"""
       Scale `x` by a factor.
       \$(METHODLIST)
       \"""
       function scale end;

julia> scale(x) = 2x;

julia> scale(x, factor) = factor * x;

julia> @doc scale
  Scale x by a factor.

  scale(x, factor)
  scale(x)
```
"""
const METHODLIST = MethodList()


#
# `TypedMethodList`
#

"""
The type for [`TYPEDMETHODLIST`](@ref) abbreviations.

$(:FIELDS)
"""
struct TypedMethodList <: Abbreviation
    return_types::Bool
end

"""
An [`Abbreviation`](@ref) that lists methods like [`METHODLIST`](@ref), with argument types
and the inferred return type in each signature.

# Examples

```jldoctest
julia> \"""
       Scale `x` by a factor.
       \$(TYPEDMETHODLIST)
       \"""
       function scale end;

julia> scale(x::Int) = 2x;

julia> scale(x::Float64, factor::Float64) = factor * x;

julia> @doc scale
  Scale x by a factor.

  scale(x::Float64, factor::Float64) -> Float64
  scale(x::Int64) -> Int64
```

!!! tip "Disabling the Return Type"
    The return type is often inferred as `Any`. To leave it out, use
    `\$(DocStringExtensions.TypedMethodList(false))`.
"""
const TYPEDMETHODLIST = TypedMethodList(true)

printlisted(buf, ::MethodList, binding, func, method) = printmethod(buf, binding, func, method)
printlisted(buf, abbr::TypedMethodList, binding, func, method) =
    printmethod(buf, binding, func, method, argsig(method); print_return_types = abbr.return_types)

function format(abbr::Union{MethodList,TypedMethodList}, buf, doc)
    local binding = doc.data[:binding]
    local typesig = doc.data[:typesig]
    local modname = doc.data[:module]
    local func = Base.invokelatest(Docs.resolve, binding)
    local groups = methodgroups(func, typesig, modname; exact = false)
    if !isempty(groups)
        println(buf)
        for group in groups
            println(buf, "```julia")
            for method in group
                printlisted(buf, abbr, binding, func, method)
                println(buf)
            end
            println(buf, "```\n")
            if !isempty(group)
                local method = group[1]
                local file = string(method.file)
                local line = method.line
                local path = sourcepath(file, modname)
                local URL = url(method)
                isempty(URL) || println(buf, "defined at [`$path:$line`]($URL).")
            end
            println(buf)
        end
        println(buf)
    end
    return nothing
end


#
# `MethodSignatures`
#

"""
The type for [`SIGNATURES`](@ref) abbreviations.

$(:FIELDS)
"""
struct MethodSignatures <: Abbreviation
    show_defaults::Bool
    definition::Union{DefinitionArguments,Nothing}
end

MethodSignatures(; defaults::Bool = false) = MethodSignatures(defaults, nothing)

interpolation(abbr::MethodSignatures, expr::Expr) =
    MethodSignatures(abbr.show_defaults, definition_arguments(expr, abbr.show_defaults))

"""
An [`Abbreviation`](@ref) that prints the signatures of the documented method, with argument
names and keywords but no types. See [`printmethod`](@ref) for the simplifications it
applies.

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
    generates for positional defaults are then printed as a single signature.
"""
const SIGNATURES = MethodSignatures()

function format(abbr::MethodSignatures, buf, doc)
    local binding = doc.data[:binding]
    local typesig = doc.data[:typesig]
    local modname = doc.data[:module]
    local func = Base.invokelatest(Docs.resolve, binding)
    local groups = documented_groups(methodgroups(func, typesig, modname), doc)
    local defaults = abbr.show_defaults ? abbr.definition : nothing

    if !isempty(groups)
        println(buf)
        println(buf, "```julia")
        for group in groups
            for method in collapse_defaults(group, defaults)
                printmethod(buf, binding, func, method; definition = abbr.definition)
                println(buf)
            end
        end
        println(buf, "```\n")
    end
end


#
# `TypedMethodSignatures`
#

"""
The type for [`TYPEDSIGNATURES`](@ref) abbreviations.

$(:FIELDS)
"""
struct TypedMethodSignatures <: Abbreviation
    return_types::Bool
    show_defaults::Bool
    definition::Union{DefinitionArguments,Nothing}
end

TypedMethodSignatures(return_types::Bool; defaults::Bool = false) =
    TypedMethodSignatures(return_types, defaults, nothing)

interpolation(abbr::TypedMethodSignatures, expr::Expr) =
    TypedMethodSignatures(abbr.return_types, abbr.show_defaults, definition_arguments(expr, abbr.show_defaults))

"""
An [`Abbreviation`](@ref) that prints the signatures of the documented method like
[`SIGNATURES`](@ref), with argument types and the inferred return type. See
[`printmethod`](@ref) for the simplifications it applies.

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

!!! tip "Disabling the Return Type"
    The return type is often inferred as `Any`. To leave it out, use
    `\$(DocStringExtensions.TypedMethodSignatures(false))`.

!!! tip "Showing Default Values"
    Default values of positional and keyword arguments are omitted. To show them, pass
    `defaults = true`: `\$(DocStringExtensions.TypedMethodSignatures(true; defaults = true))`.
    The methods that Julia generates for positional defaults are then printed as a single
    signature.
"""
const TYPEDSIGNATURES = TypedMethodSignatures(true)

function format(tms::TypedMethodSignatures, buf, doc)
    local binding = doc.data[:binding]
    local typesig = doc.data[:typesig]
    local modname = doc.data[:module]
    local func = Base.invokelatest(Docs.resolve, binding)
    # TODO: why is methodgroups returning invalid methods?
    # the methodgroups always appears to return a Vector and the size depends on whether parametric types are used
    # and whether default arguments are used
    local groups = documented_groups(methodgroups(func, typesig, modname), doc)
    local defaults = tms.show_defaults ? tms.definition : nothing
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
                print_return_types=tms.return_types, definition = tms.definition)
            println(buf)
        end
        println(buf, "```\n")
    end
end

#
# `FunctionName`
#

"""
The singleton type for [`FUNCTIONNAME`](@ref) abbreviations.

$(:FIELDS)
"""
struct FunctionName <: Abbreviation end

"""
An [`Abbreviation`](@ref) that prints the name of the documented function. Use it in a
signature written by hand, for example on a function with no methods yet.

The name is printed as plain text. Indent it or wrap it in backticks to format it as code.

# Examples

```jldoctest
julia> \"""
       `\$(FUNCTIONNAME)(d, θ)` calculates the log density of `d` at `θ`.
       \"""
       function logdensity end;

julia> @doc logdensity
  logdensity(d, θ) calculates the log density of d at θ.
```
"""
const FUNCTIONNAME = FunctionName()

format(::FunctionName, buf, doc) = print(buf, doc.data[:binding].var)

#
# `FunctionBody`
#

"""
The type for [`BODY`](@ref) abbreviations.

$(:FIELDS)
"""
struct FunctionBody <: Abbreviation
    body::Union{String,Nothing}
end

interpolation(::FunctionBody, expr::Expr) = FunctionBody(definition_body(expr))

"""
An [`Abbreviation`](@ref) that prints the body of the documented method definition as a
Julia code block. Short functions are sometimes best documented by their definition.

It prints nothing when the docstring is not attached to a method definition with a body.

# Examples

```jldoctest
julia> \"""
       Log-odds of the probability `p`:
       \$(BODY)
       \"""
       logit(p) = log(p / (1 - p));

julia> @doc logit
  Log-odds of the probability p:

  log(p / (1 - p))
```
"""
const BODY = FunctionBody(nothing)

function format(abbr::FunctionBody, buf, doc)
    abbr.body === nothing && return
    println(buf)
    println(buf, "```julia")
    println(buf, abbr.body)
    println(buf, "```\n")
end

#
# `TypeSignature`
#

"""
The singleton type for [`TYPEDEF`](@ref) abbreviations.
"""
struct TypeDefinition <: Abbreviation end

"""
An [`Abbreviation`](@ref) that prints the header of a type definition: `struct`,
`mutable struct`, `abstract type` or `primitive type`, then the unqualified name, the type
parameters, and the supertype unless it is `Any`. A primitive type also shows its size in
bits.

# Examples

```jldoctest
julia> \"""
       \$(TYPEDEF)
       A point in the plane.
       \"""
       struct Point{T<:Real} <: Number
           x::T
           y::T
       end

julia> @doc Point
  struct Point{T<:Real} <: Number

  A point in the plane.
```

!!! note

    The fields are not printed. Use [`FIELDS`](@ref) or [`TYPEDFIELDS`](@ref) for those.
"""
const TYPEDEF = TypeDefinition()

function print_supertype(buf, object)
    super = supertype(object)
    super != Any && print(buf, " <: ", super)
end

function print_params(buf, object)
    if !isempty(object.parameters)
        print(buf, "{")
        join(buf, object.parameters, ", ")
        print(buf, "}")
    end
end

function print_primitive_type(buf, object)
    print(buf, "primitive type ", object.name.name)
    print_supertype(buf, object)
    print(buf, " ", sizeof(object) * 8)
    println(buf)
end

function print_abstract_type(buf, object)
    print(buf, "abstract type ", object.name.name)
    print_params(buf, object)
    print_supertype(buf, object)
    println(buf)
end

function print_mutable_struct_or_struct(buf, object)
    ismutabletype(object) && print(buf, "mutable ")
    print(buf, "struct ", object.name.name)
    print_params(buf, object)
    print_supertype(buf, object)
    println(buf)
end

function format(::TypeDefinition, buf, doc)
    local binding = doc.data[:binding]
    local object = gettype(Base.invokelatest(Docs.resolve, binding))
    if isa(object, DataType)
        println(buf, "\n```julia")
        if isprimitivetype(object)
            print_primitive_type(buf, object)
        elseif isabstracttype(object)
            print_abstract_type(buf, object)
        else
            print_mutable_struct_or_struct(buf, object)
        end
        println(buf, "```\n")
    end
end


#
# `EnumInstances`
#

"""
The singleton type for [`INSTANCES`](@ref) abbreviations.
"""
struct EnumInstances <: Abbreviation end

"""
An [`Abbreviation`](@ref) that lists the instances of an enum with their values. It supports
enums defined with `@enum`, and with `@enumx` from EnumX.jl, whose instances it qualifies
with the enum's module name. It prints nothing for other objects.

# Examples

```jldoctest
julia> \"""
       A fruit.
       \$(INSTANCES)
       \"""
       @enum Fruit apple banana = 3 cherry

julia> @doc Fruit
  A fruit.

    •  apple = 0
    •  banana = 3
    •  cherry = 4
```
"""
const INSTANCES = EnumInstances()

function format(::EnumInstances, buf, doc)
    local entries = Base.invokelatest(enum_entries ∘ Docs.resolve, doc.data[:binding])
    if !isempty(entries)
        println(buf)
        for (name, value) in entries
            println(buf, "  - `", name, "` = ", value)
        end
        println(buf)
    end
    return nothing
end

enum_entries(enum::Type{<:Base.Enum}, prefix = "") =
    [(string(prefix, Symbol(instance)), Integer(instance)) for instance in instances(enum)]
# EnumX.jl documents the module that holds its enum type `T`, and callers write `Module.Name`.
enum_entries(mod::Module) = isdefined(mod, :T) ? enum_entries(mod.T, string(nameof(mod), ".")) : []
enum_entries(other, prefix = "") = []


#
# `TypeSubtypes`
#

"""
The singleton type for [`SUBTYPES`](@ref) abbreviations.
"""
struct TypeSubtypes <: Abbreviation end

"""
An [`Abbreviation`](@ref) that lists the direct subtypes of a type as Documenter.jl `@ref`
links. It prints nothing for other objects.

# Examples

```jldoctest
julia> \"""
       A shape.
       \$(SUBTYPES)
       \"""
       abstract type Shape end

julia> struct Circle <: Shape end

julia> struct Square <: Shape end

julia> @doc Shape
  A shape.

    •  Circle
    •  Square
```

!!! note

    Only subtypes defined in the type's own module, or in a module inside it, are listed,
    so a subtype another package defines is left out. A subtype in an inner module is
    qualified with that module's name.
"""
const SUBTYPES = TypeSubtypes()

function format(::TypeSubtypes, buf, doc)
    local names = Base.invokelatest(subtype_names ∘ Docs.resolve, doc.data[:binding])
    if !isempty(names)
        println(buf)
        for name in names
            println(buf, "  - [`", name, "`](@ref)")
        end
        println(buf)
    end
    return nothing
end

function subtype_names(T::Type)
    local body = Base.unwrap_unionall(T)
    body isa DataType || return String[]
    return sort!(subtype_names!(String[], body.name, parentmodule(body), ""))
end
subtype_names(other) = String[]

function subtype_names!(found, typename, mod::Module, prefix)
    for sym in names(mod; all = true)
        isdefined(mod, sym) || continue
        local obj = getfield(mod, sym)
        if obj isa Module
            obj !== mod && parentmodule(obj) === mod &&
                subtype_names!(found, typename, obj, string(prefix, sym, "."))
        elseif obj isa Type
            local body = Base.unwrap_unionall(obj)
            # Skipping aliases and types defined elsewhere lists each subtype once, by its own name.
            body isa DataType && nameof(body) === sym && parentmodule(body) === mod &&
                Base.unwrap_unionall(supertype(body)).name === typename &&
                push!(found, string(prefix, sym))
        end
    end
    return found
end

"""
The singleton type for [`README`](@ref) abbreviations.
"""
struct Readme <: Abbreviation end
"""
An [`Abbreviation`](@ref) that includes the package README: the first file in the package
root whose name contains `readme`, in any case. It prints nothing for a module that is not
part of a package.

!!! note
    The file is parsed as [Julia Markdown](https://docs.julialang.org/en/v1/stdlib/Markdown/),
    which differs from GitHub Markdown. For example, `[text][]` link shortcuts are not
    supported.
"""
const README = Readme()
"""
The singleton type for [`LICENSE`](@ref) abbreviations.
"""
struct License <: Abbreviation end
"""
An [`Abbreviation`](@ref) that includes the package license: the first file in the package
root whose name contains `license`, in any case. It prints nothing for a module that is not
part of a package.

!!! note
    The file is parsed as [Julia Markdown](https://docs.julialang.org/en/v1/stdlib/Markdown/),
    which differs from GitHub Markdown. For example, `[text][]` link shortcuts are not
    supported.
"""
const LICENSE = License()

function format(::T, buf, doc) where T <: Union{Readme,License}
    m = get(doc.data, :module, nothing)
    m === nothing && return
    path = pathof(m)
    path === nothing && return
    try # wrap in try/catch since we shouldn't error in case some IO operation goes wrong
        r = T === Readme ? r"(?i)readme(?-i)" : r"(?i)license(?-i)"
        # assume README/LICENSE is located in the root of the repo
        root = normpath(joinpath(path, "..", ".."))
        for file in readdir(root)
            if occursin(r, file)
                str = read(joinpath(root, file), String)
                write(buf, str)
                return
            end
        end
    catch
    end
end


#
# `DocStringTemplate`
#

"""
The singleton type for [`DOCSTRING`](@ref) abbreviations.
"""
struct DocStringTemplate <: Abbreviation end

"""
An [`Abbreviation`](@ref) that marks where a [`@template`](@ref) places the original
docstring. Every template must contain it.

# Examples

```jldoctest
julia> module Shapes
       using DocStringExtensions
       @template (FUNCTIONS, METHODS) = \"""
           \$(DOCSTRING)
           Part of the `Shapes` module.
           \"""
       "Compute the area of a square."
       area(side) = side^2
       end;

julia> @doc Shapes.area
  Compute the area of a square. Part of the Shapes module.
```

!!! warning

    Use `DOCSTRING` only in templates. Showing an ordinary docstring that contains it
    throws an error.
"""
const DOCSTRING = DocStringTemplate()

# NOTE: no `format` needed for this 'mock' abbreviation.

is_docstr_template(::DocStringTemplate) = true
is_docstr_template(other) = false

#
# `TemplateOverride`
#

"""
The type for [`NOTEMPLATE`](@ref) abbreviations.

`TemplateOverride(category)` applies the module's [`@template`](@ref) for `category` to the
docstring it appears in, in place of the template for the documented object's own category.
`category` is one of the categories `@template` accepts, and the module must define a
template for it before the docstring.

$(:FIELDS)
"""
struct TemplateOverride <: Abbreviation
    category::Union{Symbol,Nothing}
    TemplateOverride(category::Symbol) = new(checked_category(category))
    TemplateOverride(::Nothing) = new(nothing)
end

"""
An [`Abbreviation`](@ref) that stops the module's [`@template`](@ref) applying to the
docstring it appears in. It prints nothing.

# Examples

```jldoctest
julia> module Shapes
       using DocStringExtensions
       @template (FUNCTIONS, METHODS) = \"""
           \$(TYPEDSIGNATURES)
           \$(DOCSTRING)
           \"""
       \"""
       Compute the area of a square.
       \$(NOTEMPLATE)
       \"""
       area(side::Int) = side^2
       end;

julia> @doc Shapes.area
  Compute the area of a square.
```

!!! tip "Using Another Category's Template"
    To apply the module's template for another category in place of skipping the template,
    use `\$(DocStringExtensions.TemplateOverride(:DEFAULT))` with that category.
"""
const NOTEMPLATE = TemplateOverride(nothing)

format(::TemplateOverride, buf, doc) = nothing

# The docstring's `TemplateOverride` if it has one, otherwise the `inferred` category.
function template_selector(text, inferred::Symbol)
    for part in text
        part isa TemplateOverride && return part
    end
    return inferred
end

"""
Internal abbreviation type used to wrap templated docstrings.

`Location` is a `Symbol`, either `:before` or `:after`. `dict` stores a
reference to a module's templates. `expr` is the documented expression, which is
passed to [`interpolation`](@ref) for each part of the template.
"""
struct Template{Location} <: Abbreviation
    dict::Dict{Symbol,Vector{Any}}
    expr::Expr
end

function format(abbr::Template, buf, doc)
    for part in template_parts(abbr, template_selector(doc.text, template_key(doc)))
        # We don't call `DocStringExtensions.format` here since we need to be
        # able to format any content in docstrings, rather than just
        # abbreviations.
        Docs.formatdoc(buf, doc, part)
    end
end

# The parts of the template for `key` found before the `DOCSTRING` abbreviation, or after it.
function template_parts(abbr::Template, key::Symbol)
    local parts = get_template(abbr.dict, key)
    return Any[interpolation(parts[index], abbr.expr) for index in included_range(abbr, parts)]
end
function template_parts(abbr::Template, override::TemplateOverride)
    local category = override.category
    category === nothing && return Any[]
    haskey(abbr.dict, category) || throw(ArgumentError(
        "`TemplateOverride` category `$category` has no template. " *
        "Define one with `@template $category = \"...\"` before the docstring."
    ))
    return template_parts(abbr, category)
end

function included_range(abbr::Template, parts::Vector)
    # Select the correct indexing depending on what we find.
    build_range(::Template{:before}, index) = 1:(index - 1)
    build_range(::Template{:after}, index) = (index + 1):lastindex(parts)
    # Search for index from either the front or back.
    find_index(::Template{:before}) = findfirst(is_docstr_template, parts)
    find_index(::Template{:after}) = findlast(is_docstr_template, parts)
    # Find and return the correct indices.
    return build_range(abbr, find_index(abbr))
end

# Runs as each templated docstring is registered. Specialising on the documented object would
# compile, and cache in the documenting package's image, an instance for every function.
function template_key(binding::Docs.Binding, @nospecialize(typesig))
    # Local helper methods for extracting the template key from a docstring.
    ismacro(b::Docs.Binding) = startswith(string(b.var), '@')
    objname(@nospecialize(obj::Union{Function,Module,DataType,UnionAll,Core.IntrinsicFunction}), b::Docs.Binding) = nameof(obj)
    objname(@nospecialize(obj), b::Docs.Binding) = Symbol("") # Empty to force resolving to `:CONSTANTS` below.
    # Select the key returned based on input argument types.
    _key(@nospecialize(::Module), @nospecialize(sig), binding)   = :MODULES
    _key(@nospecialize(::Function), ::typeof(Union{}), binding)  = ismacro(binding) ? :MACROS : :FUNCTIONS
    _key(@nospecialize(::Function), @nospecialize(sig), binding) = ismacro(binding) ? :MACROS : :METHODS
    _key(@nospecialize(::DataType), ::typeof(Union{}), binding)  = :TYPES
    _key(@nospecialize(::UnionAll), ::typeof(Union{}), binding)  = :TYPES
    _key(@nospecialize(::DataType), @nospecialize(sig), binding) = :METHODS
    _key(@nospecialize(::UnionAll), @nospecialize(sig), binding) = :METHODS
    _key(@nospecialize(other), @nospecialize(sig), binding)      = :DEFAULT

    obj = Base.invokelatest(Docs.resolve, binding)
    name = objname(obj, binding)
    key = name === binding.var ? _key(obj, typesig, binding) : :CONSTANTS
    return key
end
template_key(doc::Docs.DocStr) = template_key(doc.data[:binding], doc.data[:typesig])
