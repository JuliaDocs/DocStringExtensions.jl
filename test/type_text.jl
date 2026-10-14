@testset "type_text" begin
    let io = IOContext(devnull, :module => AnonymousTypeVarsTestModule),
            Grid = AnonymousTypeVarsTestModule.Grid

        # `show` prints `Type{<:Grid}` by its generated name on Julia 1.14, inside a `Vararg` too.
        @test DSE.type_text(Tuple{Vararg{Type{<:Grid}}}, io) == (
            VERSION >= v"1.7" ? "Tuple{Vararg{Type{<:Grid}}}" :
                VERSION >= v"1.6" ? "Tuple{Vararg{Type{<:Grid}, N} where N}" :
                "Tuple{Vararg{Type{<:Grid},N} where N}"
        )
        # `Ref{<:Any}` is `Ref`, which `show` prints bare on every version.
        @test DSE.type_text(Ref{<:Any}, io) == "Ref"
        # A bound prints in parentheses only when it needs them for its own `where`.
        @test DSE.typevar_text(TypeVar(:T, Ref{<:Real}), io) == "T<:Ref{<:Real}"
        @test DSE.typevar_text(TypeVar(:T, Ref{<:Grid}, Any), io) == "T>:Ref{<:Grid}"
        @test DSE.typevar_text(TypeVar(:T, Pair{S, S} where {S}), io) ==
            (VERSION >= v"1.6" ? "T<:(Pair{S, S} where S)" : "T<:(Pair{S,S} where S)")
        @test DSE.typevar_text(TypeVar(:T, Int8, Real), io) == "Int8<:T<:Real"
        # A generated variable that `<:T` can't write prints as the `const` alias it came from, in
        # the docstring's module or a module of a type it names.
        Mod = AnonymousTypeVarsTestModule
        aliases = DSE.alias_context(Mod, io)
        @test DSE.type_text(Mod.ScalarOrVec{<:AbstractFloat}, aliases) == "ScalarOrVec{<:AbstractFloat}"
        @test DSE.type_text(Mod.Keyed{Symbol, <:Real}, aliases) == "Keyed{Symbol, <:Real}"
        @test DSE.type_text(Mod.Keyed{<:Integer, <:Real}, aliases) == "Keyed{<:Integer, <:Real}"
        @test DSE.type_text(Mod.SmallV{<:Int8}, IOContext(devnull)) ==
            "Main.AnonymousTypeVarsTestModule.SmallV{<:Int8}"
        @test DSE.type_text(AbstractVecOrMat{<:Real}, IOContext(devnull)) == "AbstractVecOrMat{<:Real}"
        # Inside a parameter too. Julia caches `Ref{X}` by type equality, so rebuilding `Ref{X}`
        # from a renamed `X` would bring back the generated name.
        @test DSE.type_text(Ref{Mod.ScalarOrRef{<:AbstractFloat}}, aliases) ==
            "Ref{ScalarOrRef{<:AbstractFloat}}"
        # From Julia 1.14 `Type{T}` is a `TypeEq`, and `show` prints `Type{<:T}` inside it by its
        # generated name when `T` needs its module.
        @test DSE.type_text(Type{Mod.ScalarOrRef{<:AbstractFloat}}, aliases) ==
            "Type{ScalarOrRef{<:AbstractFloat}}"
        # Of two aliases for the same type, the first by name.
        @test DSE.type_text(Mod.TwoAliases.Crate{<:Real}, DSE.alias_context(Mod.TwoAliases)) ==
            "Main.AnonymousTypeVarsTestModule.TwoAliases.Box{<:Real}"
        # An alias that declares its own type variable, or holds a `Vararg` or `Type{T}`.
        @test DSE.type_text(Mod.RefsOf{<:Real}, aliases) == "RefsOf{<:Real}"
        @test DSE.type_text(Mod.TupleOf{<:Real}, aliases) == "TupleOf{<:Real}"
        @test DSE.type_text(Mod.Kinds{<:Real}, aliases) == "Kinds{<:Real}"
        # A `Vararg` with a count: `Rows` in the docstring's module, `NTuple` from `Base` otherwise.
        let s = TypeVar(Symbol("#s9"), Real), N = TypeVar(:N)
            @test DSE.type_text(UnionAll(s, Tuple{Vararg{s, N}}), DSE.unionall_env([N], aliases)) == "Rows{<:Real, N}"
            @test DSE.type_text(UnionAll(s, Tuple{Vararg{s, N}}), DSE.unionall_env([N])) == "NTuple{N, <:Real}"
        end
        # An alias whose bounds rule out the arguments the match finds gives way to the next one.
        @test DSE.type_text(Mod.RefRef{<:Real}, aliases) == "RefRef{<:Real}"
        @test DSE.type_text(Mod.Keyed{Symbol, <:Real}, aliases) == "Keyed{Symbol, <:Real}"
        # With no alias, the type prints as `show` prints it, here after `RefsOf` fails on the
        # inner variable's bound.
        let s = TypeVar(Symbol("#s9"), Real), S = TypeVar(:S, s, Any)
            @test DSE.type_text(UnionAll(s, Vector{UnionAll(S, Ref{S})}), aliases) == (
                VERSION >= v"1.14-" ? "Vector{Ref{S} where S>:var\"#s9\"} where var\"#s9\"<:Real" :
                    VERSION >= v"1.6" ? "Array{Ref{S} where S>:var\"#s9\", 1} where var\"#s9\"<:Real" :
                    "Array{Ref{S} where S>:#s9,1} where #s9<:Real"
            )
        end
        # With no alias, the type prints as `show` prints it.
        let s = TypeVar(Symbol("#s9"), AbstractFloat)
            @test DSE.type_text(UnionAll(s, Union{s, Ref{s}}), io) == (
                VERSION >= v"1.6" ? "Union{Ref{var\"#s9\"}, var\"#s9\"} where var\"#s9\"<:AbstractFloat" :
                    "Union{Ref{#s9}, #s9} where #s9<:AbstractFloat"
            )
        end
        @test DSE.type_text(Type{Type{<:Grid}}, IOContext(devnull)) ==
            "Type{Type{<:Main.AnonymousTypeVarsTestModule.Grid}}"
        # From Julia 1.7 a `Vararg` keeps its count, and a parameter written `<:Any` prints as the
        # alias that `show` finds.
        if VERSION >= v"1.7"
            @test DSE.type_text(Tuple{String, Vararg{Type{<:Grid}, N}} where {N}, io) ==
                "Tuple{String, Vararg{Type{<:Grid}, N}} where N"
            @test DSE.type_text(Vector{<:Any}, io) == "Vector"
            @test DSE.type_text(Dict{Symbol, <:Any}, io) == "Dict{Symbol}"
        end
    end
end
