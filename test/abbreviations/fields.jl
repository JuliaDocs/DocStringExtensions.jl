@testset "FIELDS" begin
    doc = Docs.DocStr(Core.svec(), nothing, Dict())
    @testset "type fields" begin
        doc.data = Dict(
            :binding => Docs.Binding(M, :T),
            :fields => Dict(
                :a => "one",
                :b => "two",
            ),
        )
        str = formatted(FIELDS, doc)
        @test_reference ro_path("fields.txt") str

        str = formatted(TYPEDFIELDS, doc)
        @test_reference ro_path("typed_fields.txt") str
    end

    @testset "field defaults" begin
        names = [:Options, :Settings, :Verbatim, :Hidden, :Plain]
        str = join([rendered(:(FieldDefaultsTestModule.$name)) for name in names], "\n")
        @test_reference ro_path("field_defaults.txt") str
        @test rendered(:(FieldDefaultsTestModule.Templated.Config)) ==
            "  * `a::Float64 = 1.0`\n\ntype `Config`\n"
    end

    @testset "code_span" begin
        @test DSE.code_span("a = 1") == "`a = 1`"
        @test DSE.code_span("a = \"`b`\"") == "```a = \"`b`\"```"
        @test DSE.code_span("a = ``") == "``` a = `` ```"
        @test DSE.code_span("a = \"```\"") == "`````a = \"```\"`````"
        @test DSE.first_line("begin\n    x\nend") == "begin …"
    end
end
