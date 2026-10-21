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
        withenv("DOCSTRINGEXTENSIONS_SIGNATURE_WIDTH" => "4") do
            @test DSE.printmethod(b, f, m) == "K(;\n    a\n)"
        end
    end
    let b = Docs.Binding(Main, :f),
            f = () -> 1,
            m = first(methods(f))

        # A call without arguments has nothing to wrap.
        withenv("DOCSTRINGEXTENSIONS_SIGNATURE_WIDTH" => "1") do
            @test DSE.printmethod(b, f, m) == "f()"
        end
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
    let b = Docs.Binding(M, :k_24),
            f = M.k_24,
            m = first(methods(f))

        # A bound that names another type parameter keeps its alias, which `show` writes from
        # Julia 1.6.
        typed = DSE.printmethod(IOBuffer(), b, f, m, DSE.argsig(m); returns = false)
        vector = VERSION < v"1.6" ? "Array{T,1}" : "Vector{T}"
        @test String(take!(typed)) == "k_24(x::T, y::S) where {T, S<:$vector}"
    end
    let b = Docs.Binding(M, :k_25),
            f = M.k_25,
            m = first(methods(f))

        # A parameter that inference cannot work out prints as its bound. Julia 1.3 and later
        # name it from a list inference keeps; earlier versions name it `_1`, printed as is.
        typed = String(take!(DSE.printmethod(IOBuffer(), b, f, m, DSE.argsig(m))))
        expected = VERSION < v"1.3" ? "Main.M.Pairing{_1,typeof(sin)} where _1" : "Main.M.Pairing{<:Any, typeof(sin)}"
        @test typed == "k_25(x) -> $expected"
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
        # A return type inferred as `Any` tells the reader nothing, so it is left out.
        @test String(take!(DSE.printmethod(IOBuffer(), b, f, m, Tuple{Any}))) == "f(x)"
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
        io = IOContext(devnull)
        unbounded = last(Tuple{Vararg{Int8}}.parameters)
        counted = last((Tuple{Vararg{Int8, N}} where {N}).body.parameters)
        @test DSE.typed_argument("x", Any, io) == "x"
        @test DSE.typed_argument("x", Int8, io) == "x::Int8"
        @test DSE.typed_argument("_", Int8, io) == "::Int8"
        @test DSE.typed_argument("_", Any, io) == "_"
        @test DSE.typed_argument("xs", unbounded, io) == "xs::Int8..."
        @test DSE.typed_argument("_", unbounded, io) == "::Int8..."
        @test DSE.typed_argument("xs", counted, io) == "xs::Vararg{Int8, N}"
    end
end
