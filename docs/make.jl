# Add docs/lib to LOAD_PATH so that we could load the Showcase module like a library.
let doclib = abspath(joinpath(@__DIR__, "Showcase", "src"))
    doclib in LOAD_PATH || pushfirst!(LOAD_PATH, doclib)
end

using Documenter, DocStringExtensions
import Showcase

makedocs(
    sitename = "DocStringExtensions.jl",
    modules = [DocStringExtensions, Showcase],
    clean = false,
    pages = Any[
        "Home" => "index.md",
        "Showcase" => "showcase.md",
        "Internals" => "internals.md",
    ],
    format = Documenter.HTML(
        assets = ["assets/favicon.ico"],
        analytics = "UA-136089579-3",
    ),
)

deploydocs(
    repo = "github.com/JuliaDocs/DocStringExtensions.jl.git",
)
