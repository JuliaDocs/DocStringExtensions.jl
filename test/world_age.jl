@testset "world-age safety" begin
    # Test that formatting works correctly when called from a stale world age,
    # which is the scenario that triggers failures on Julia 1.12+ with binding
    # partitions. We use invokelatest in the test to simulate the world-age gap
    # that occurs when docstrings are formatted during macro expansion.
    # Each case reuses the reference of the matching `format` testset above.
    latest(abbr, doc) = Base.invokelatest(formatted, abbr, doc)
    doc = Docs.DocStr(Core.svec(), nothing, Dict())

    doc.data = Dict(
        :binding => Docs.Binding(M, :h),
        :typesig => Tuple{Int, Int, Int},
        :module => M,
    )
    @test_reference typed_signatures_h_reference() latest(DSE.TYPEDSIGNATURES, doc)

    doc.data = Dict(
        :binding => Docs.Binding(M, :f),
        :typesig => Tuple{Any},
        :module => M,
    )
    @test_reference ro_path("method_signatures.txt") latest(DSE.SIGNATURES, doc)
    str = with_test_repo(() -> latest(DSE.METHODLIST, doc))
    @test_reference method_lists_reference() redact_local_info(str)

    doc.data = Dict(
        :binding => Docs.Binding(M, :l_1),
        :typesig => Union{},
        :module => M,
    )
    str = with_test_repo(() -> latest(DSE.TYPEDMETHODLIST, doc))
    @test_reference typed_method_lists_reference("typed_method_lists") redact_local_info(str)

    doc.data = Dict(
        :binding => Docs.Binding(M, :T),
        :fields => Dict(:a => "one", :b => "two"),
    )
    @test_reference ro_path("fields.txt") latest(DSE.FIELDS, doc)

    doc.data = Dict(
        :binding => Docs.Binding(M, :AbstractType1),
        :typesig => Union{},
        :module => M,
    )
    @test_reference ro_path("typedef1.txt") latest(DSE.TYPEDEF, doc)

    doc.data = Dict(
        :binding => Docs.Binding(Main, :M),
        :typesig => Union{},
    )
    @test_reference ro_path("module_exports.txt") latest(DSE.EXPORTS, doc)
    @test_reference ro_path("module_exports.txt") latest(DSE.PUBLIC, doc)
    @test_reference module_imports_reference() latest(DSE.IMPORTS, doc)

    doc.data = Dict(:binding => Docs.Binding(M, :Color), :typesig => Union{})
    @test_reference ro_path("enum_instances.txt") latest(DSE.INSTANCES, doc)
    doc.data = Dict(:binding => Docs.Binding(M, :Fruit), :typesig => Union{})
    @test_reference ro_path("enumx_instances.txt") latest(DSE.INSTANCES, doc)
    doc.data = Dict(:binding => Docs.Binding(M, :Shape), :typesig => Union{})
    @test_reference ro_path("subtypes.txt") latest(DSE.SUBTYPES, doc)

    # A module defined after this function started is newer than its world.
    function stale_exports()
        Core.eval(
            Main, :(
                module StaleExports
                export area
                area() = 1
                end
            )
        )
        doc.data = Dict(:binding => Docs.Binding(Main, :StaleExports), :typesig => Union{})
        return formatted(DSE.EXPORTS, doc)
    end
    @test stale_exports() == "\n  - [`area`](@ref)\n\n"

    # `@template` defines the module's templates during this expansion, after its world.
    function expand_with_template(mod)
        return macroexpand(
            mod, quote
                @template DEFAULT = "(STALE) $(DOCSTRING)"
                "doc" f(x) = x
            end
        )
    end
    stale_templates = Module()
    Core.eval(stale_templates, :(using DocStringExtensions))
    expanded = @test_nowarn expand_with_template(stale_templates)
    @test occursin("Template{:before}", string(expanded))
end
