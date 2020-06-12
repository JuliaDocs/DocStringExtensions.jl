# Showcase

```@meta
CurrentModule = Showcase
```

This page shows how the various abbreviations look.
The docstrings themselves can be found in `docs/Showcase/src/Showcase.jl`.

## Modules

```@docs
Showcase
```

## Functions and methods

```@docs
foo
foo(::Int)
foo(::String)
```

### Type parameters

[`TYPEDSIGNATURES`](@ref) can also handle type parameters. However, the resulting signatures
may not be as clean as in the code since they have to be reconstructed from Julia's internal
representation:

```@docs
bar(x::AbstractArray{T}, y::T) where {T <: Integer}
bar(x::AbstractArray{T}, ::String) where {T <: Integer}
bar(x::AbstractArray{T}, y::U) where {T <: Integer, U <: AbstractString}
```

## Types

```@docs
Foobar
```
