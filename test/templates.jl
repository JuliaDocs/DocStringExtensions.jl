@testset "templates" begin
    @test occursin("(DEFAULT)", rendered(:(TemplateTests.K)))
    @test rendered(:(TemplateTests.U)) == "(DEFAULT)\n\nconstant `U{S}`\n"
    @test occursin("(TYPES)", rendered(:(TemplateTests.T)))
    @test length(collect(eachmatch(r"\(TYPES\)", rendered(:(TemplateTests.S))))) == 1
    @test occursin("(TYPES)", rendered(:(TemplateTests.ISSUE_115)))
    @test occursin("(TYPES)", rendered(:(TemplateTests.P)))
    # Issue 147: abstract types have their own category.
    @test rendered(:(TemplateTests.A)) == "(ABSTRACTTYPES)\n\nabstract type `A`\n"
    @test rendered(:(TemplateTests.AP)) == "(ABSTRACTTYPES)\n\nabstract type `AP{S}`\n"
    @test occursin("(METHODS, MACROS)", rendered(:(TemplateTests.f)))
    @test occursin("(METHODS, MACROS)", rendered(:(TemplateTests.g)))
    @test occursin("(METHODS, MACROS)", rendered(:(TemplateTests.h)))
    @test occursin("(METHODS, MACROS)", rendered(:(TemplateTests.@m)))
    @test occursin("(METHODS, MACROS)", rendered(:(TemplateTests.r)))
    @test occursin("(METHODS, MACROS)", rendered(:(TemplateTests.early)))
    @test rendered(:(TemplateTests.never_defined)) == "(DEFAULT)\n\nname `never_defined` documented but never defined\n"
    # A method defined through a `const` alias is still a method.
    @test occursin("(METHODS, MACROS)", rendered(:(TemplateTests.aliased)))
    @test occursin("(METHODS, MACROS)", rendered(:(TemplateTests.Point2)))
    @test occursin("(METHODS, MACROS)", rendered(:(TemplateTests.Inner)))
    @test occursin("(METHODS, MACROS)", rendered(:(TemplateTests.InnerParametric)))
    # `@doc` returns the binding before Julia 1.13 and the documented value from 1.13.
    doc_value(v) = v isa Docs.Binding ? (:binding, v.var) : (:value, nameof(v))
    @test doc_value(TemplateTests.DOC_VALUE) == doc_value(Untemplated.DOC_VALUE)
    @test rendered(:(TemplateTests.LateTemplate.before)) == "method `before`\n"
    @test rendered(:(TemplateTests.LateTemplate.after)) == "(LATE)\n\nmethod `after`\n"
    # A template applies to a docstring expanded in the same block, before the template is set.
    @test rendered(:(TemplateTests.BlockTemplate.inside)) == "(BLOCK)\n\nmethod `inside`\n"
    # Bindings documented together each get the template for their own category.
    @test occursin("(DEFAULT)", rendered(:(TemplateTests.paired)))
    @test occursin("(TYPES)", rendered(:(TemplateTests.Paired)))
    @test occursin("(DEFAULT)", rendered(:(TemplateTests.Documented)))
    @test occursin("(DEFAULT)", rendered(:(TemplateTests.Redocumented)))
    # Issue 158: a docstring can skip its template or use another category's.
    @test rendered(:(TemplateTests.opted_out)) == "method `opted_out`\n"
    @test rendered(:(TemplateTests.early_opted_out)) == "method `early_opted_out` documented before it is defined\n"
    @test rendered(:(TemplateTests.OptedOut)) == "`@kwdef` struct `OptedOut`\n"
    @test rendered(:(TemplateTests.redirected)) == "(DEFAULT)\n\nmethod `redirected`\n"

    @test occursin("(DEFAULT)", rendered(:(TemplateTests.InnerModule.K)))
    @test occursin("(DEFAULT)", rendered(:(TemplateTests.InnerModule.T)))
    @test occursin("field docs for x", rendered(:(TemplateTests.InnerModule.T)))
    @test occursin("(DEFAULT)", rendered(:(TemplateTests.InnerModule.A)))
    @test occursin("(METHODS, MACROS)", rendered(:(TemplateTests.InnerModule.f)))
    @test occursin("(MACROS)", rendered(:(TemplateTests.InnerModule.@m)))
    @test occursin("(METHODS, MACROS)", rendered(Expr(:., :(TemplateTests.InnerModule), QuoteNode(Symbol("@notmacro")))))

    @test occursin("(TYPES)", rendered(:(TemplateTests.OtherModule.T)))
    @test occursin("(TYPES)", rendered(:(TemplateTests.OtherModule.ISSUE_115)))
    # A module without an `ABSTRACTTYPES` template documents abstract types with `TYPES`.
    @test occursin("(TYPES)", rendered(:(TemplateTests.OtherModule.A)))
    @test occursin("(MACROS)", rendered(:(TemplateTests.OtherModule.@m)))
    @test rendered(:(TemplateTests.OtherModule.f)) == "method `f`\n"

    # Issue 151: a template without `DOCSTRING` is rejected where it is defined.
    for template in ("test", Expr(:string, "test ", :SIGNATURES))
        mod = Module()
        Core.eval(mod, :(using DocStringExtensions))
        @test_throws ArgumentError Core.eval(mod, :(@template DEFAULT = $template))
    end
    # A category no docstring belongs to is rejected where it is defined.
    let mod = Module()
        Core.eval(mod, :(using DocStringExtensions))
        result = @test_throws ArgumentError Core.eval(mod, :(@template (TYPES, STRUCTS) = "$DOCSTRING"))
        @test result.value.msg ==
            "`@template` category `STRUCTS` is not one of DEFAULT, FUNCTIONS, METHODS, MACROS, TYPES, ABSTRACTTYPES, MODULES, CONSTANTS."
    end
    # Issue 158: an override names a category the module defines a template for.
    @test_throws ArgumentError DSE.TemplateOverride(:STRUCTS)
    let mod = Module()
        Core.eval(mod, :(using DocStringExtensions))
        Core.eval(mod, :(@template DEFAULT = "$DOCSTRING"))
        docstr = Expr(:string, "docs", :(DocStringExtensions.TemplateOverride(:TYPES)))
        result = @test_throws ArgumentError Core.eval(mod, :(@doc $docstr f(x) = x))
        @test result.value.msg ==
            "`TemplateOverride` category `TYPES` has no template. Define one with `@template TYPES = \"...\"` before the docstring."
    end
    # Issue 147: naming `ABSTRACTTYPES` explicitly does not fall back to `TYPES`.
    let mod = Module(:Parent)
        Core.eval(mod, :(using DocStringExtensions))
        Core.eval(mod, :(@template TYPES = "$DOCSTRING"))
        docstr = Expr(:string, "docs", :(DocStringExtensions.TemplateOverride(:ABSTRACTTYPES)))
        @test_throws ArgumentError Core.eval(mod, :(@doc $docstr abstract type A end))
        result = @test_throws ArgumentError Core.eval(mod, :(@template ABSTRACTTYPES = Parent))
        @test occursin("`Parent` has no `ABSTRACTTYPES` template", result.value.msg)
    end
    # Issue 117: copying a template the source module does not define names the module and category.
    let mod = Module(:Parent)
        Core.eval(mod, :(using DocStringExtensions))
        Core.eval(mod, :(module Child end))
        for source in (:Parent, :Child)
            result = @test_throws ArgumentError Core.eval(mod, :(@template MODULES = $source))
            @test occursin("`$source` has no `MODULES` template", result.value.msg)
        end
    end

    @testset "template_key" begin
        @test @inferred(DSE.template_key(Docs.Binding(M, :f), Union{})) === :FUNCTIONS
        @test @inferred(DSE.template_key(Docs.Binding(M, :T), Union{})) === :TYPES
        @test @inferred(DSE.template_key(Docs.Binding(Main, :M), Union{})) === :MODULES
    end

    @test @inferred(DSE.module_templates(TemplateTests)) isa Dict{Symbol, Vector}
end
