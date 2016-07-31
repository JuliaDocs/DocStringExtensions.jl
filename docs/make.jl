using Documenter, DocStringExtensions

makedocs(
    modules = [DocStringExtensions],
    clean = false,
)

deploydocs(
    deps = Deps.pip("pygments", "mkdocs", "mkdocs-material"),
    repo = "github.com/JuliaDocs/DocStringExtensions.jl.git",
)

