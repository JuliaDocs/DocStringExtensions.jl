using DocStringExtensions
using Test
import Markdown
import LibGit2
import REPL
import DeepDiffs

const DSE = DocStringExtensions

include("reference.jl")
include("helpers.jl")

# Modules whose docstrings the tests render.
include("fixtures/templates.jl")
include("fixtures/interpolation.jl")
include("fixtures/defaults.jl")
include("fixtures/field_defaults.jl")
include("fixtures/constructors.jl")
include("fixtures/other_definitions.jl")
include("fixtures/destructuring.jl")
include("fixtures/body.jl")
include("fixtures/TestModule/M.jl")
# `public` is a syntax error before Julia 1.11.
VERSION >= v"1.11" && include("fixtures/public.jl")
# A package with a submodule in a subdirectory of `src`.
let packages = joinpath(@__DIR__, "fixtures", "packages")
    packages in LOAD_PATH || push!(LOAD_PATH, packages)
end
import Nested

@testset "DocStringExtensions" begin
    include("base_assumptions.jl")
    include("interface.jl")
    include("definitions.jl")
    include("methods.jl")
    include("printmethod.jl")
    include("abbreviations/fields.jl")
    include("abbreviations/module_names.jl")
    include("abbreviations/imports.jl")
    include("abbreviations/methodlist.jl")
    include("abbreviations/signatures.jl")
    include("abbreviations/functionname.jl")
    include("abbreviations/body.jl")
    include("abbreviations/typedef.jl")
    include("abbreviations/instances.jl")
    include("abbreviations/subtypes.jl")
    include("abbreviations/package_files.jl")
    include("templates.jl")
    include("hook.jl")
    include("world_age.jl")
    # Every docstring in the package parses, abbreviations included.
    @test DSE.parsedocs(DSE) === nothing
end
# `include` returns its last value, and a REPL would print the whole testset.
nothing
