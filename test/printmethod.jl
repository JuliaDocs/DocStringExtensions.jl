@testset "printmethod" begin
    let b = Docs.Binding(M, :T),
            f = M.T,
            m = first(methods(f))

        @test DSE.printmethod(b, f, m) == "T(a, b, c)"
    end
    let b = Docs.Binding(M, :K),
            f = M.K,
            m = first(methods(f))

        @test DSE.printmethod(b, f, m) == "K(; a)"
    end
    let b = Docs.Binding(Main, :f),
            f = (x, ::String) -> x,
            m = first(methods(f))

        @test DSE.printmethod(b, f, m) == "f(x, ::String)"
        typed = DSE.printmethod(IOBuffer(), b, f, m, Tuple{Any, String}; returns = false)
        @test String(take!(typed)) == "f(x, ::String)"
    end
    let b = Docs.Binding(Main, :f),
            f = (x::Ref{<:Real}, y::Ref{>:Int}, ::Type{<:Integer}) -> x,
            m = first(methods(f))

        # A parameter written `<:T` prints as written, not as the type variable Julia generates.
        @test DSE.printmethod(b, f, m) == "f(x, y, ::Type{<:Integer})"
        typed = DSE.printmethod(IOBuffer(), b, f, m, DSE.argsig(m); returns = false)
        @test String(take!(typed)) == "f(x::Ref{<:Real}, y::Ref{>:$Int}, ::Type{<:Integer})"
    end
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
    let b = Docs.Binding(M, :k_23),
            f = M.k_23,
            m = first(methods(f))

        @test DSE.printmethod(b, f, m) == "k_23(_, ::Val{N}, ::String...)"
    end
    let b = Docs.Binding(M, :k_19),
            f = M.k_19,
            m = first(methods(f))

        # `T` appears only in the bound of `S`.
        typed = DSE.printmethod(IOBuffer(), b, f, m, DSE.argsig(m); returns = false)
        @test String(take!(typed)) == "k_19(x::S) where {T, S<:Ref{T}}"
    end
    let b = Docs.Binding(M, :Param2),
            f = M.Param2,
            m = first(methods(M.Param2{Int}, Tuple{Any}))

        # `Param2{T}` leaves the second parameter free.
        @test DSE.printmethod(b, f, m) == "Param2{T}(b)"
        typed = DSE.printmethod(IOBuffer(), b, f, m, DSE.argsig(m); returns = false)
        @test String(take!(typed)) == "Param2{T}(b) where T<:Number"
    end
    let b = Docs.Binding(M, :k_20),
            f = M.k_20,
            m = first(methods(f))

        typed = DSE.printmethod(IOBuffer(), b, f, m, DSE.argsig(m); returns = false)
        @test String(take!(typed)) == "k_20(xs::Vararg{T, N}) where {T, N}"
    end
    let b = Docs.Binding(M, :k_11),
            f = M.k_11,
            m = first(methods(f))

        @test DSE.printmethod(b, f, m) == "k_11(x, xs...)"
    end
    let b = Docs.Binding(M, :f),
            f = M.f,
            m = first(methods(f))

        @test DSE.printmethod(b, f, m) == "f(x)"
        let result = @test_throws ErrorException DSE.printmethod(IOBuffer(), b, f, m, Ref)
            @test result.value.msg == "Expected `typeof(Ref{T})` to be `Tuple` or `UnionAll` but found `DataType`"
        end
    end
    let b = Docs.Binding(M, :g_1),
            f = M.g_1,
            m = first(methods(f))

        # Issue 157: inference cannot run a generator on abstract argument types.
        typed = DSE.printmethod(IOBuffer(), b, f, m, Tuple{Any})
        @test String(take!(typed)) == "g_1(x)"
    end
    let b = Docs.Binding(M, :overlapping_generated),
            f = M.overlapping_generated,
            m = which(f, Tuple{Integer})

        # Inference also runs the generator of an overlapping `@generated` method.
        typed = DSE.printmethod(IOBuffer(), b, f, m, Tuple{Integer})
        @test String(take!(typed)) == "overlapping_generated(x::Integer)"
    end
    let b = Docs.Binding(Main, :f),
            f = () -> (),
            m = first(methods(f))

        @test DSE.printmethod(b, f, m) == "f()"
    end
    let b = Docs.Binding(Main, :f),
            f = (a) -> (),
            m = first(methods(f))

        @test DSE.printmethod(b, f, m) == "f(a)"
    end
    let b = Docs.Binding(Main, :f),
            f = (; a = 1) -> (),
            m = first(methods(f))

        @test DSE.printmethod(b, f, m) == "f(; a)"
    end
    let b = Docs.Binding(Main, :f),
            f = (; a = 1, b = 2) -> (),
            m = first(methods(f))
        # Keywords are not ordered, so check for both combinations.
        @test DSE.printmethod(b, f, m) in ("f(; a, b)", "f(; b, a)")
    end
    let b = Docs.Binding(Main, :f),
            f = (; a...) -> (),
            m = first(methods(f))

        @test DSE.printmethod(b, f, m) == "f(; a...)"
    end
    let b = Docs.Binding(Main, :f),
            f = (; a = 1, b = 2, c...) -> (),
            m = first(methods(f))
        # Keywords are not ordered, so check for both combinations.
        @test DSE.printmethod(b, f, m) in ("f(; a, b, c...)", "f(; b, a, c...)")
    end
    # Issue 97: typed signatures print the declared types of keyword arguments.
    typed(name) = let f = getfield(M, name), m = first(methods(f))
        String(take!(DSE.printmethod(IOBuffer(), Docs.Binding(M, name), f, m, DSE.argsig(m); returns = false)))
    end
    @test typed(:i_3) == "i_3(x::T; y) where T"
    @test typed(:i_4) == "i_4(x; y::T, z::U) where {T, U}"
    @test typed(:i_5) == "i_5(x::T; a::$Int, b::T, c, d...) where T<:Real"
    @test typed(:i_6) == "i_6(xs::$Int...; a::$Int)"
    @test DSE.printmethod(Docs.Binding(M, :i_5), M.i_5, first(methods(M.i_5))) == "i_5(x; a, b, c, d...)"

    @testset "append_defaults" begin
        let d = definition_arguments_with_defaults(:(g(x = 1, y = 2, z = 3; kwargs...) = x)),
                m = which(M.g, Tuple{Any})

            @test DSE.append_defaults(["x"], ["kwargs..."], ["kwargs..."], m, d) == (["x=1"], ["kwargs..."])
        end
    end

    @testset "used_typevars" begin
        let T = TypeVar(:T), S = TypeVar(:S, Ref{T}), U = TypeVar(:U)
            # `T` is used only in the bound of `S`.
            @test DSE.used_typevars([T, S, U], Any[Tuple{S}]) == Any[T, S]
            @test DSE.used_typevars([T, U], Any[Tuple{Int}, Vector{U}]) == Any[U]
            @test DSE.used_typevars([T, U], Any[Tuple{Int}]) == Any[]
        end
        let A = TypeVar(Symbol("#s1"), Real), S = TypeVar(:S, Ref{A})
            # A type variable Julia generated stays out of the `where` clause, even in a bound.
            @test DSE.used_typevars([A, S], Any[Tuple{S}, Vector{A}]) == Any[S]
        end
    end

    @testset "typed_argument" begin
        typestring(t) = sprint(show, t)
        unbounded = last(Tuple{Vararg{Int8}}.parameters)
        counted = last((Tuple{Vararg{Int8, N}} where {N}).body.parameters)
        @test DSE.typed_argument("x", Any, typestring) == "x"
        @test DSE.typed_argument("x", Int8, typestring) == "x::Int8"
        @test DSE.typed_argument("_", Int8, typestring) == "::Int8"
        @test DSE.typed_argument("_", Any, typestring) == "_"
        @test DSE.typed_argument("xs", unbounded, typestring) == "xs::Int8..."
        @test DSE.typed_argument("_", unbounded, typestring) == "::Int8..."
        @test DSE.typed_argument("xs", counted, typestring) == "xs::Vararg{Int8, N}"
    end
end
