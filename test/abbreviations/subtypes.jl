@testset "SUBTYPES" begin
    doc = Docs.DocStr(Core.svec(), nothing, Dict())
    @testset "subtypes" begin
        # Direct subtypes only, each once by its own name, inner modules qualified.
        doc.data = Dict(:binding => Docs.Binding(M, :Shape), :typesig => Union{})
        @test_reference ro_path("subtypes.txt") formatted(SUBTYPES, doc)

        # A parametric supertype matches whatever parameters its subtypes pass it.
        doc.data = Dict(:binding => Docs.Binding(M, :Container), :typesig => Union{})
        @test formatted(SUBTYPES, doc) == "\n  - [`Box`](@ref)\n\n"

        doc.data = Dict(:binding => Docs.Binding(M, :Circle), :typesig => Union{})
        @test formatted(SUBTYPES, doc) == ""

        doc.data = Dict(:binding => Docs.Binding(M, :f), :typesig => Union{})
        @test formatted(SUBTYPES, doc) == ""
    end
end
