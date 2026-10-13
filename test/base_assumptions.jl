    @testset "Base assumptions" begin
        # The package heavily relies on type and docsystem-related methods and types from
        # Base, which are generally undocumented and their behaviour might change at any
        # time. This set of tests is tests and documents the assumptions the package makes
        # about them.
        #
        # The testset is not comprehensive -- i.e. DocStringExtensions makes use of
        # undocumented features that are not tested here. Should you come across anything
        # like that, please add a test here.
        #

        # How `Docs.docm` registers a docstring.
        #
        # Used in src/hook.jl by forward_doc_calls(), which replaces each call to the
        # `Docs.doc!` function object, and by the template_hook() method for the `@doc` calls
        # that `@__doc__` leaves to be expanded later. forward_doc!() takes the same arguments:
        # a signature, or none for a module.
        let calls(f, ex) = ex isa Expr ? Int(f(ex)) + reduce(+, Int[calls(f, arg) for arg in ex.args]; init = 0) : 0,
            doc_call(ex) = Meta.isexpr(ex, :call) && ex.args[1] === Docs.doc!,
            doc_call_with(nargs) = ex -> doc_call(ex) && length(ex.args) == nargs + 1,
            doc_macro(ex) = Meta.isexpr(ex, :macrocall) && ex.args[1] === Symbol("@doc"),
            docm(ex) = Docs.docm(LineNumberNode(1), @__MODULE__, "docs", ex)

            @test calls(doc_call_with(4), docm(:(f(x) = x))) == 1
            @test calls(doc_call_with(3), docm(:(module DocmModule end))) == 1
            @test calls(doc_call, docm(:((f, g)))) == 2
            let out = docm(:(Base.@kwdef struct DocmStruct end)),
                arity = VERSION < v"1.6" ? 5 : 7

                @test calls(doc_call, out) == 0
                @test calls(ex -> doc_macro(ex) && length(ex.args) == arity, out) == 1
            end
        end

        # Telling an abstract type from a concrete one, parametric or not.
        #
        # Used in src/templates.jl by template_key() to pick the `ABSTRACTTYPES` template.
        @test Base.isabstracttype(AbstractVector)
        @test !Base.isabstracttype(Vector)
        @test !Base.isabstracttype(Int8)

        # Getting keyword arguments of a method.
        #
        # Used in src/methods.jl for the keywords() function.
        #
        # The methodology is based on a snippet in Base at base/replutil.jl:572-576
        # (commit 3b45cdc9aab0). It uses the undocumented Base.kwarg_decl() function.
        @test isdefined(Base, :kwarg_decl)
        # Its signature is kwarg_decl(m::Method, kwtype::DataType). The second argument
        # should be the type of the kwsorter from the corresponding MethodTable.
        @test isa(methods(M.j_1), Base.MethodList)
        get_mt(func) = VERSION ≥ v"1.12" ? Core.methodtable : methods(func).mt
        local mt = get_mt(M.j_1)
        @test isa(mt, Core.MethodTable)
        if Base.fieldindex(Core.MethodTable, :kwsorter, false) > 0
            @test isdefined(mt, :kwsorter)
        end
        # .kwsorter is not always defined -- namely, it seems when none of the methods
        # have keyword arguments:
        @test isdefined(get_mt(M.f), :kwsorter) === false
        # M.j_1 has two methods. Fetch the single argument one..
        local m = which(M.j_1, (Any,))
        @test isa(m, Method)
        # .. which should have a single keyword argument, :y
        # Base.kwarg_decl returns a Vector{Any} of the keyword arguments.
        local kwargs = VERSION < v"1.4.0-DEV.215" ? Base.kwarg_decl(m, typeof(mt.kwsorter)) : Base.kwarg_decl(m)
        @test isa(kwargs, Vector)
        @test kwargs == [:y]
        # Base.kwarg_decl will return a Tuple{} for some reason when called on a method
        # that does not have any arguments
        m = which(M.j_1, (Any, Any)) # fetch the no-keyword method
        if VERSION < v"1.4.0-DEV.215"
            @test Base.kwarg_decl(m, typeof(get_mt(M.j_1).kwsorter)) == Tuple{}()
        else
            @test Base.kwarg_decl(m) == []
        end

        # A method with keyword arguments ends by calling a body method, whose arguments are
        # the keywords, then the function, then the positional arguments.
        #
        # Used in src/methods.jl by keyword_body() and keyword_types().
        slots(body) = Base.uncompressed_ast(body).slotnames[2:body.nargs]
        let body = DSE.keyword_body(first(methods(M.i_5)))
            @test slots(body)[[1:4; end]] == [:a, :b, :c, :d, :x]
            @test Base.unwrap_unionall(body.sig).parameters[2] === Int
        end
        @test slots(DSE.keyword_body(first(methods(M.i_6))))[[1, end]] == [:a, :xs]

        # Whether a method's last positional argument is a vararg.
        #
        # Used in src/printmethod.jl for the untyped printmethod() method.
        @test first(methods(M.k_11)).isva
        @test !first(methods(M.f)).isva

        # Whether a name is exported, since `names` also returns `public` names on 1.11+.
        #
        # Used in src/abbreviations/module_names.jl for the EXPORTS abbreviation.
        @test Base.isexported(M, :f)
        @test !Base.isexported(M, :g_1)

        # Whether a method is `@generated`.
        #
        # Used in src/methods.jl by method_return_type(). Julia before 1.10 has
        # no `Base.hasgenerator`, and the `hasgenerator` shim reads the `generator` field.
        @test DSE.hasgenerator(first(methods(M.g_1)))
        @test !DSE.hasgenerator(first(methods(M.f)))

        # `Base.return_types` lists one type per method, in the order `methods` lists them.
        #
        # Used in src/methods.jl for the method_return_type() function.
        @test collect(methods(M.overlapping, Tuple{Integer})) ==
            [which(M.overlapping, Tuple{Int8}), which(M.overlapping, Tuple{Integer})]
        @test Base.return_types(M.overlapping, Tuple{Integer}) == [Int8, String]

        # A method's argument types, without the function type.
        #
        # Used in src/methods.jl by argsig().
        @test Base.tuple_type_tail(first(methods(M.k_0)).sig) == (Tuple{T} where T)
        @test Base.tuple_type_tail(which(M.k_13, Tuple{Int}).sig) == Tuple{Any,Vararg{Any}}

        # Recognising a vararg argument type and its element type.
        #
        # Used in src/printmethod.jl for the typed printmethod() method, and in src/methods.jl
        # by argument_types() and expanded_vararg().
        let varargs = Tuple{Int,Vararg{Real}}.types
            @test Base.isvarargtype(varargs[2])
            @test !Base.isvarargtype(varargs[1])
            @test !Base.isvarargtype(Union{})
            @test Base.unwrapva(varargs[2]) === Real
        end
        @test Base.unwrapva(last((Tuple{Vararg{T}} where T).body.types)) isa TypeVar

        # A fixed-count vararg expands in `method.sig`, and its `n` is a field of `Vararg`.
        #
        # Used in src/methods.jl by expanded_vararg() and vararg_length().
        @test first(methods(M.k_16)).isva
        @test Base.tuple_type_tail(first(methods(M.k_16)).sig) == Tuple{Real,Int,Int}
        @test DSE.vararg_length(Vararg{Int,2}) == 2
        @test DSE.vararg_length(last(Tuple{Int,Vararg{Int}}.types)) === nothing
        let N = TypeVar(:N)
            @test DSE.vararg_length(Vararg{Int,N}) === N
        end

        # A constructor written as `T{P}(...)` is a method of `Type{T{P}}`, which
        # `Base._methods_by_ftype` finds by its full signature, and its docstring records
        # where it was written.
        #
        # Used in src/methods.jl by constructor_methods(), matched_methods(),
        # constructor_parameters() and documented_groups().
        let ctor = first(methods(M.Param{Int}, Tuple{})),
            multidoc = Docs.meta(M)[Docs.Binding(M, :Param)],
            data = multidoc.docs[first(multidoc.order)].data,
            tt = Base.rewrap_unionall(Tuple{Type{Base.unwrap_unionall(M.Param)}}, M.Param)

            @test isempty(methods(M.Param, Tuple{}))
            @test DSE.matched_methods(tt) == [ctor]
            @test DSE.istypeoftype(Base.unwrap_unionall(ctor.sig).parameters[1])
            @test data[:path] == String(ctor.file)
            @test data[:linenumber] < ctor.line
        end

        # Printing a type parameter by name inside a method's `where` clause.
        #
        # Used in src/printmethod.jl for the typed printmethod() method.
        let T = TypeVar(:T, Number)
            @test Base.has_typevar(Tuple{Vector{T}}, T)
            @test !Base.has_typevar(Tuple{String}, T)
            @test sprint(show, Union{Nothing,T}; context = :unionall_env => T) == "Union{Nothing, T}"
            @test sprint(show, T) == "T<:Number"
        end

        # Rendering default values as source text.
        #
        # Used in src/definitions.jl for the definition_arguments() function.
        @test sprint(Base.show_unquoted, :(zero(T))) == "zero(T)"
        @test sprint(Base.show_unquoted, :x) == "x"
        @test sprint(Base.show_unquoted, "x") == "\"x\""
        @test sprint(Base.show_unquoted, QuoteNode(:x)) == ":x"
        # A destructured argument prints as it is written.
        @test sprint(Base.show_unquoted, :((a, (b, c)))) == "(a, (b, c))"
        @test Base.remove_linenums!(Expr(:block, LineNumberNode(1), :x)) == Expr(:block, :x)

        # Where Julia places the constructors that a struct definition creates.
        #
        # Used in src/methods.jl by struct_constructors(), which takes the constructors
        # defined no later than the definition's last line, and by self_type() for the default
        # constructor of a parametric type.
        let mod = Module()
            Base.include_string(mod, """
                struct Defaults
                    x::Float64
                end
                struct Inner
                    x::Float64
                    Inner() = new(0.0)
                end
                struct Parametric{T}
                    x::T
                end
                """, "constructors.jl")
            local constructors(name) = Base.invokelatest(methods, Base.invokelatest(getfield, mod, name))
            # No later than the last field, the definition's last line before `end`.
            @test all(m -> String(m.file) == "constructors.jl" && m.line <= 2, constructors(:Defaults))
            @test [m.line for m in constructors(:Inner)] == [6]
            local parametric = Base.invokelatest(getfield, mod, :Parametric)
            local defaults = Base.invokelatest(methods, parametric{Int})
            # Julia 1.10 stores it under `Type{Parametric{T}} where T`, Julia 1.6 under `Type{Parametric{T}}`.
            @test all(m -> DSE.istypeoftype(Base.unwrap_unionall(DSE.self_type(m))), defaults)
        end
    end
