# [Functions and methods](@id examples-functions)

```@meta
CurrentModule = Examples
```

The docstrings for these abbreviations are in the [reference](@ref reference-functions).

```@eval
Main.example_source("functions.jl")
```

The docstrings render as:

```@docs
foo
foo(::Int)
foo(::String)
```

## Type parameters

[`TYPEDSIGNATURES`](@ref) rebuilds a signature from Julia's internal representation, so type
parameters may print differently from the source:

```@eval
Main.example_source("parameters.jl")
```

The docstrings render as:

```@docs
bar(x::AbstractArray{T}, y::T) where {T <: Integer}
bar(x::AbstractArray{T}, ::String) where {T <: Integer}
bar(x::AbstractArray{T}, y::U) where {T <: Integer, U <: AbstractFloat}
```

## Function bodies

[`BODY`](@ref) prints the code of the documented method. Julia prints it from the parsed
expression, so comments are dropped and some syntax is normalised, such as `for x in xs`
printing as `for x = xs`:

```@eval
Main.example_source("bodies.jl")
```

The docstring renders as:

```@docs
duplicates
```
