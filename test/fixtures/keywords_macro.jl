# Like Parameters.jl's `@with_kw`, defines a positional inner constructor and a keyword
# constructor at lines of this file, outside the struct definition's file.
macro keywords(ex)
    local name = ex.args[2]
    local fields = filter(f -> Meta.isexpr(f, :(=)), ex.args[3].args)
    local keywords = [Expr(:kw, f.args[1].args[1], f.args[2]) for f in fields]
    local names = [f.args[1].args[1] for f in fields]
    ex.args[3].args = Any[Meta.isexpr(f, :(=)) ? f.args[1] : f for f in ex.args[3].args]
    push!(ex.args[3].args, :($name($(names...)) = new($(names...))))
    return esc(
        quote
            Base.@__doc__ $ex
            $name(; $(keywords...)) = $name($(names...))
        end
    )
end
