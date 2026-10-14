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

    # Each later line of a field's docstring is indented under its list item.
    @testset "multi-line field docstring" begin
        doc.data = Dict(
            :binding => Docs.Binding(M, :T),
            :fields => Dict(:a => "one\n\ncontinued  \nand more"),
        )
        @test_reference ro_path("fields_multiline.txt") formatted(FIELDS, doc)
    end

    @testset "field defaults" begin
        names = [:Options, :Settings, :Verbatim, :Hidden, :Plain]
        str = join([rendered(:(FieldDefaultsTestModule.$name)) for name in names], "\n")
        @test_reference ro_path("field_defaults.txt") str
        @test rendered(:(FieldDefaultsTestModule.Templated.Config)) ==
            "  * `a::Float64 = 1.0`\n\ntype `Config`\n"
    end

    # A field type written with `<:T` prints as written, not as the type variable Julia generates.
    @testset "anonymous type parameters" begin
        str = rendered(:(AnonymousTypeVarsTestModule.Fields))
        @test_reference ro_path("typed_fields_anonymous.txt") str
    end

    @testset "code_span" begin
        @test DSE.code_span("a = 1") == "`a = 1`"
        @test DSE.code_span("a = \"`b`\"") == "```a = \"`b`\"```"
        @test DSE.code_span("a = ``") == "``` a = `` ```"
        @test DSE.code_span("a = \"```\"") == "`````a = \"```\"`````"
        @test DSE.first_line("begin\n    x\nend") == "begin …"
    end
end
