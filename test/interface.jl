@testset "interface" begin
    doc = Docs.DocStr(Core.svec(), nothing, Dict())
    buf = IOBuffer()

    # Errors.
    let result = @test_throws ErrorException DSE.format(nothing, buf, doc)
        @test result.value.msg == "`format` not implemented for `Nothing`."
    end

    @testset "doc data" begin
        data = Dict{Symbol, Any}(:binding => Docs.Binding(M, :f), :module => M)
        doc = Docs.DocStr(Core.svec(), nothing, data)
        @test @inferred(DSE.doc_binding(doc)) == Docs.Binding(M, :f)
        @test @inferred(DSE.doc_module(doc)) === M
    end

    if VERSION >= v"1.11"
        @testset "public names" begin
            names = [
                :Abbreviation, :format, :interpolation, :MethodSignatures, :TypedMethodSignatures,
                :MethodList, :TypedMethodList, :TypeFields, :TemplateOverride,
            ]
            @test filter(name -> !Base.ispublic(DSE, name), names) == Symbol[]
        end
    end

    @testset "Interpolation" begin
        @test occursin("f(x)", rendered(:(InterpolationTestModule.f)))
        @test occursin("x + 2", rendered(:(InterpolationTestModule.g)))
        @test rendered(:(InterpolationTestModule.Templated.h)) == "h(x)\n\nmethod `h`\n"
        @test rendered(:(InterpolationTestModule.StructOnlyTemplate.k)) == "method `k`\n"
    end
end
