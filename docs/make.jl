using Documenter, DocStringExtensions

makedocs(
    sitename = "DocStringExtensions.jl",
    modules = [DocStringExtensions],
    clean = false,
    pages = Any["Home" => "index.md"],
)

deploydocs(
    repo = "github.com/JuliaDocs/DocStringExtensions.jl.git",
)
