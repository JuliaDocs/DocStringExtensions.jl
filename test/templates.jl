@testset "templates" begin
        let fmt = expr -> Markdown.plain(eval(:(@doc $expr)))
            @test occursin("(DEFAULT)", fmt(:(TemplateTests.K)))
            @test fmt(:(TemplateTests.U)) == "(DEFAULT)\n\nconstant `U{S}`\n"
            @test occursin("(TYPES)", fmt(:(TemplateTests.T)))
            @test length(collect(eachmatch(r"\(TYPES\)", fmt(:(TemplateTests.S))))) == 1
            @test occursin("(TYPES)", fmt(:(TemplateTests.ISSUE_115)))
            @test occursin("(TYPES)", fmt(:(TemplateTests.P)))
            # Issue 147: abstract types have their own category.
            @test fmt(:(TemplateTests.A)) == "(ABSTRACTTYPES)\n\nabstract type `A`\n"
            @test fmt(:(TemplateTests.AP)) == "(ABSTRACTTYPES)\n\nabstract type `AP{S}`\n"
            @test occursin("(METHODS, MACROS)", fmt(:(TemplateTests.f)))
            @test occursin("(METHODS, MACROS)", fmt(:(TemplateTests.g)))
            @test occursin("(METHODS, MACROS)", fmt(:(TemplateTests.h)))
            @test occursin("(METHODS, MACROS)", fmt(:(TemplateTests.@m)))
            @test occursin("(METHODS, MACROS)", fmt(:(TemplateTests.r)))
            @test occursin("(METHODS, MACROS)", fmt(:(TemplateTests.early)))
            @test occursin("(METHODS, MACROS)", fmt(:(TemplateTests.Inner)))
            @test occursin("(METHODS, MACROS)", fmt(:(TemplateTests.InnerParametric)))
            # `@doc` returns the binding before Julia 1.13 and the documented value from 1.13.
            doc_value(v) = v isa Docs.Binding ? (:binding, v.var) : (:value, nameof(v))
            @test doc_value(TemplateTests.DOC_VALUE) == doc_value(Untemplated.DOC_VALUE)
            @test fmt(:(TemplateTests.LateTemplate.before)) == "method `before`\n"
            @test fmt(:(TemplateTests.LateTemplate.after)) == "(LATE)\n\nmethod `after`\n"
            # Bindings documented together each get the template for their own category.
            @test occursin("(DEFAULT)", fmt(:(TemplateTests.paired)))
            @test occursin("(TYPES)", fmt(:(TemplateTests.Paired)))
            @test occursin("(DEFAULT)", fmt(:(TemplateTests.Documented)))
            @test occursin("(DEFAULT)", fmt(:(TemplateTests.Redocumented)))
            # Issue 158: a docstring can skip its template or use another category's.
            @test fmt(:(TemplateTests.opted_out)) == "method `opted_out`\n"
            @test fmt(:(TemplateTests.early_opted_out)) == "method `early_opted_out` documented before it is defined\n"
            @test fmt(:(TemplateTests.OptedOut)) == "`@kwdef` struct `OptedOut`\n"
            @test fmt(:(TemplateTests.redirected)) == "(DEFAULT)\n\nmethod `redirected`\n"

            @test occursin("(DEFAULT)", fmt(:(TemplateTests.InnerModule.K)))
            @test occursin("(DEFAULT)", fmt(:(TemplateTests.InnerModule.T)))
            @test occursin("field docs for x", fmt(:(TemplateTests.InnerModule.T)))
            @test occursin("(DEFAULT)", fmt(:(TemplateTests.InnerModule.A)))
            @test occursin("(METHODS, MACROS)", fmt(:(TemplateTests.InnerModule.f)))
            @test occursin("(MACROS)", fmt(:(TemplateTests.InnerModule.@m)))

            @test occursin("(TYPES)", fmt(:(TemplateTests.OtherModule.T)))
            @test occursin("(TYPES)", fmt(:(TemplateTests.OtherModule.ISSUE_115)))
            # A module without an `ABSTRACTTYPES` template documents abstract types with `TYPES`.
            @test occursin("(TYPES)", fmt(:(TemplateTests.OtherModule.A)))
            @test occursin("(MACROS)", fmt(:(TemplateTests.OtherModule.@m)))
            @test fmt(:(TemplateTests.OtherModule.f)) == "method `f`\n"
        end

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
end
