using Documenter, DocStringExtensions

makedocs(
    sitename = "DocStringExtensions.jl",
    modules = [DocStringExtensions],
    format = :html,
    clean = false,
    pages = Any["Home" => "index.md"],
)

deploydocs(
    target = "build",
    deps = nothing,
    make = nothing,
    repo = "github.com/JuliaDocs/DocStringExtensions.jl.git",
    julia = "1.0",
)

