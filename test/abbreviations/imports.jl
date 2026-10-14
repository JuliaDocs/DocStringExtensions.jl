@testset "IMPORTS" begin
    doc = Docs.DocStr(Core.svec(), nothing, Dict())
    # Module imports.
    doc.data = Dict(
        :binding => Docs.Binding(Main, :M),
        :typesig => Union{},
    )
    str = formatted(IMPORTS, doc)
    @test_reference module_imports_reference() str

    # Any other object throws instead of crashing Julia.
    doc.data = Dict(
        :binding => Docs.Binding(M, :f),
        :typesig => Union{},
    )
    @test_throws TypeError formatted(IMPORTS, doc)
end
