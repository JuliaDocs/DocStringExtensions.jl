@testset "EXPORTS and PUBLIC" begin
    doc = Docs.DocStr(Core.svec(), nothing, Dict())
    doc.data = Dict(
        :binding => Docs.Binding(Main, :M),
        :typesig => Union{},
    )
    # Module exports.
    str = formatted(EXPORTS, doc)
    @test_reference ro_path("module_exports.txt") str

    # Module public names, which are only the exports in a module without `public`.
    str = formatted(PUBLIC, doc)
    @test_reference ro_path("module_exports.txt") str

    # Issue 190: `public` names are public but not exported.
    if VERSION >= v"1.11"
        doc.data = Dict(
            :binding => Docs.Binding(Main, :PublicNames),
            :typesig => Union{},
        )
        str = formatted(EXPORTS, doc)
        @test_reference ro_path("module_exports_with_public.txt") str
        str = formatted(PUBLIC, doc)
        @test_reference ro_path("module_public.txt") str
    end
end
