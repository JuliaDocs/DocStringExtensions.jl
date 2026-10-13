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
        let fmt = expr -> Markdown.plain(eval(:(@doc $expr)))
            names = [:Options, :Settings, :Verbatim, :Hidden, :Plain]
            str = join([fmt(:(FieldDefaultsTestModule.$name)) for name in names], "\n")
            @test_reference ro_path("field_defaults.txt") str
            @test fmt(:(FieldDefaultsTestModule.Templated.Config)) ==
                "  * `a::Float64 = 1.0`\n\ntype `Config`\n"
        end
    end

        @testset "code_span" begin
            @test DSE.code_span("a = 1") == "`a = 1`"
            @test DSE.code_span("a = \"`b`\"") == "```a = \"`b`\"```"
            @test DSE.code_span("a = ``") == "``` a = `` ```"
            @test DSE.code_span("a = \"```\"") == "`````a = \"```\"`````"
            @test DSE.first_line("begin\n    x\nend") == "begin …"
        end
end
