"""
This docstring belongs to the `Examples` module.

[`EXPORTS`](@ref) lists the exported names:

$(EXPORTS)

[`PUBLIC`](@ref) also lists the names declared `public`, here `bar` and `Fruit`:

$(PUBLIC)

[`IMPORTS`](@ref) lists the modules loaded with `using`:

$(IMPORTS)

[`README`](@ref) includes the package README, shown between the rules:

---

$(README)

---

[`LICENSE`](@ref) includes the package license the same way:

---

$(LICENSE)

---
"""
module Examples
using DocStringExtensions

export foo, Foobar
public bar, Fruit

include("functions.jl")
include("parameters.jl")
include("types.jl")
include("enums.jl")
include("templates.jl")

end
