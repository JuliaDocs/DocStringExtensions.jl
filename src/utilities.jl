
#
# Utilties.
#

"""
Given a callable object `f` and a signature `sig` collect, filter, and sort the matching
methods. All methods not defined within `mod` are discarded. Sorting is based on file name
and line number. When the `exact` keyword is set to `true` then only exact matching methods
will be returned, not all subtypes as well.

$(:signatures)
"""
function filtermethods(f, sig, mod; exact = false)
    local mt = sig == Union{} ? methods(f) : methods(f, sig)
    local results = Method[]
    for method in mt
        if getfield(method, :module)::Module == mod
            if exact
                if Base.tuple_type_tail(method.sig) == sig
                    push!(results, method)
                end
            else
                push!(results, method)
            end
        end
    end
    local sorter = function(a, b)
        sa, sb = string(a.file), string(b.file)
        comp = sa < sb ? -1 : sa > sb ? 1 : 0
        comp == 0 ? a.line < b.line : comp < 0
    end
    return sort!(results, lt = sorter)
end

"""
Parse all docstrings defined within a module `mod`.

$(:signatures)
"""
function parsedocs(mod::Module)
    for (binding, multidoc) in Docs.meta(mod)
        for (typesig, docstr) in multidoc.docs
            Docs.parsedoc(docstr)
        end
    end
end


"""
Print a simplified representation of a method signature to `buffer`.

$(:signatures)

Simplifications include:

  * no `TypeVar`s;
  * no types;
  * no keyword default values;
  * `?` printed where `#unused#` arguments are found.

# Examples

```julia
f(x; a = 1, b...) = x
sig = printmethod(Docs.Binding(Main, :f), f, first(methods(f)))
```
"""
function printmethod(buffer::IOBuffer, binding::Docs.Binding, func, method::Method)
    # TODO: print qualified?
    print(buffer, binding.var)
    print(buffer, "(")
    join(buffer, arguments(method), ", ")
    local kws = keywords(func, method)
    if !isempty(kws)
        print(buffer, "; ")
        join(buffer, kws, ", ")
    end
    print(buffer, ")")
    return buffer
end

printmethod(b, f, m) = takebuf_string(printmethod(IOBuffer(), b, f, m))


"""
Returns the list of keywords for a particular method `m` of a function `func`.

$(:signatures)

# Examples

```julia
f(x; a = 1, b...) = x
kws = keywords(f, first(methods(f)))
```
"""
function keywords(func, m::Method)
    local table = methods(func).mt
    if isdefined(table, :kwsorter)
        local kwsorter = table.kwsorter
        local signature = Base.tuple_type_cons(Vector{Any}, m.sig)
        if method_exists(kwsorter, signature)
            local method = which(kwsorter, signature)
            if isdefined(method, :lambda_template)
                local template = method.lambda_template
                # `.slotnames` is a `Vector{Any}`. Convert it to the right type.
                local args = map(Symbol, template.slotnames[(template.nargs + 1):end])
                # Only return the usable symbols, not ones that aren't identifiers.
                filter!(arg -> !contains(string(arg), "#"), args)
                # Keywords *may* not be sorted correctly. We move the vararg one to the end.
                local index = findfirst(arg -> endswith(string(arg), "..."), args)
                if index > 0
                    args[index], args[end] = args[end], args[index]
                end
                return args
            end
        end
    end
    return Symbol[]
end


"""
Returns the list of arguments for a particular method `m`.

$(:signatures)

# Examples

```julia
f(x; a = 1, b...) = x
args = arguments(first(methods(f)))
```
"""
function arguments(m::Method)
    if isdefined(m, :lambda_template)
        local template = m.lambda_template
        if isdefined(template, :slotnames)
            local args = map(template.slotnames[1:template.nargs]) do arg
                arg === Symbol("#unused#") ? "?" : arg
            end
            return filter(arg -> arg !== Symbol("#self#"), args)
        end
    end
    return Symbol[]
end

