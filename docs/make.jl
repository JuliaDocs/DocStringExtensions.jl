using Documenter, DocStringExtensions

makedocs(
    sitename = "DocStringExtensions.jl",
    modules = [DocStringExtensions],
    clean = false,
    pages = Any["Home" => "index.md"],
    format = Documenter.HTML(
        assets = ["assets/favicon.ico"],
    ),
)

deploydocs(
    repo = "github.com/JuliaDocs/DocStringExtensions.jl.git",
)
