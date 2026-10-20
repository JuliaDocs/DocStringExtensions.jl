# DocStringExtensions.jl changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## [v0.10.1](https://github.com/JuliaDocs/DocStringExtensions.jl/releases/tag/v0.10.1) - 2026-10-20

### Changed

- Improved the TTFX of the package by reducing specializations and adding a
  precompilation workload ([#309](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/309)).

## [v0.10.0](https://github.com/JuliaDocs/DocStringExtensions.jl/releases/tag/v0.10.0) - 2026-10-14

### Breaking

- `@template` rejects a category no docstring belongs to, such as a misspelled name, with an `ArgumentError`. It used to store a template that never applied, so a package with such a category now fails to precompile until the category is corrected or removed ([#223](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/223))
- `@template` throws an `ArgumentError` for a template string without `$(DOCSTRING)`, including a plain string literal, when the template is defined. Some of these templates used to load and fail with a `MethodError` only when Julia displayed a docstring. A package that defines one now fails to precompile ([#151](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/151))
- More docstrings get a template, and some get a different one. A docstring now gets its template when it sits in the same `begin` block as the `@template` ([#288](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/288)), documents a bare existing name such as `"..." f` ([#291](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/291)), or documents a parametric type's constructor ([#226](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/226)). A method defined through a `const` alias gets `METHODS` where it got `CONSTANTS` ([#289](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/289)). A function named like a macro, such as `var"@f"`, no longer gets `MACROS` ([#263](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/263)). Bindings documented together each get their own category's template ([#210](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/210)). Where a docstring repeats by hand what its template prints, the text now appears twice

### Added

- Add `TYPEDMETHODLIST`, which lists methods like `METHODLIST` but with argument and return types. `TypedMethodList(returns = false)` leaves out the return types ([#150](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/150), [#197](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/197))
- Add `TypedMethodSignatures(returns = false)`, which renders typed signatures without return types ([#159](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/159), [#179](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/179))
- Add a `returns` option to `MethodSignatures` and `MethodList` that follows each signature with its inferred return type. `MethodSignatures` and `TypedMethodSignatures` also take a string, such as `returns = "success::Bool"`, which they print after `->` in place of the inferred type ([#206](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/206), [#246](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/246))
- Add the `DOCSTRINGEXTENSIONS_RETURN_ARROW` and `DOCSTRINGEXTENSIONS_SIGNATURE_WIDTH` environment variables. A reader sets them to change the arrow before return types, such as to `→`, and the width at which a signature wraps to one argument per line, 60 by default ([#252](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/252), [#267](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/267))
- Add a `defaults = true` option to `MethodSignatures` and `TypedMethodSignatures` that prints default argument values, with the methods generated for positional defaults collapsed into one signature ([#19](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/19), [#107](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/107), [#194](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/194))
- Add a `defaults = :brackets` option to `MethodSignatures` and `TypedMethodSignatures`. It prints the collapsed signature without default values. Each optional positional argument appears in brackets. Any other symbol passed as `defaults` throws an `ArgumentError` ([#206](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/206), [#247](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/247))
- Add `PUBLIC` to list a module's public names, both exported and declared `public` ([#190](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/190))
- Add `INSTANCES` to list the instances of an enum with their values. It supports `@enum` and EnumX.jl's `@enumx` ([#171](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/171))
- Add `SUBTYPES` to list the direct subtypes of a type as links. It lists only subtypes defined in the type's own module or a module inside it ([#47](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/47), [#154](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/154), [#227](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/227))
- Add `BODY` to print the body of the documented method definition as a Julia code block ([#54](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/54), [#237](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/237))
- Add `NOTEMPLATE`, which stops a module's `@template` applying to the docstring it appears in. `TemplateOverride(category)` applies the template for another category instead ([#158](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/158), [#240](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/240))
- Add the `ABSTRACTTYPES` template category for abstract types. A module without one documents abstract types with its `TYPES` template, as before ([#147](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/147), [#241](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/241))
- `SIGNATURES` and `TYPEDSIGNATURES` in the docstring of a macro print it as its caller writes it, such as `@m a b`. The `__source__` and `__module__` arguments and the inferred return type are left out. They printed nothing before. `METHODLIST` and `TYPEDMETHODLIST` list a macro the same way. For a vararg macro they printed its hidden arguments, and for any other macro nothing ([#262](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/262))
- `SIGNATURES` and `TYPEDSIGNATURES` in the docstring of a struct list the constructors its definition creates. They printed nothing before ([#71](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/71), [#245](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/245))
- Declare the interface for writing an abbreviation public on Julia 1.11 and later: `Abbreviation`, `format` and `interpolation`. A new guide covers it ([#86](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/86), [#303](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/303))
- Declare the types that take abbreviation options public on Julia 1.11 and later, such as `MethodSignatures` and `TypeFields`. Each one appears on its topic's reference page ([#303](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/303))
- Add `TypeFields(; types, defaults)`, whose keywords match the other option types ([#303](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/303))

### Changed

- Signatures leave out a return type inferred as `Any`, as they already did for `Nothing`. `-> Any` says only that inference could not work out the type ([#301](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/301), [#298](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/298))
- The manual splits into Examples and Reference sections with one page per topic. Each example page prints its source above the rendered docstrings, and new pages cover `PUBLIC`, `INSTANCES`, and `@template` with `DOCSTRING`. The package docstring is rewritten. A Setup page covers adding the package, templates, and Documenter. The docstrings of the package, `@template` and every abbreviation except `README` and `LICENSE` carry examples as doctests, which the docs build checks against the real output. They replace hand-written samples that had drifted from it ([#122](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/122), [#215](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/215))
- `SIGNATURES` prints an unnamed argument with a declared type as `::T`, as `TYPEDSIGNATURES` does, so `foo(::Val{N})` no longer prints as `foo(_)`. An untyped unnamed argument still prints as `_` ([#161](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/161), [#235](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/235))
- `TYPEDSIGNATURES` and `TYPEDMETHODLIST` print the declared type of each keyword argument, such as `f(x; n::Int64)`. An untyped keyword and a `kwargs...` keyword print without one ([#97](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/97), [#244](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/244))
- `FIELDS` and `TYPEDFIELDS` print each field's default value, such as `retries::Int64 = 3`, for structs defined with `Base.@kwdef` or a macro that uses the same syntax. `TypeFields(defaults = false)` hides them ([#182](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/182), [#245](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/245))
- `@template` applies a template when its docstring is defined, not when it is displayed, so a templated docstring no longer stores the documented expression in the package image. A docstring for a binding that does not exist yet keeps its template until display. Bindings documented together, such as `@doc "..." (f, T)`, each get the template for their own category, where they all used the last binding's ([#210](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/210))

### Deprecated

- `TypeFields(types::Bool)` is deprecated in favour of `TypeFields(types = ...)` ([#303](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/303))

### Fixed

- Fix inferred return types printing the names inference gives the type parameters it cannot work out, such as `-> Pair{_A, Int} where _A`. They print as their bound, `-> Pair{<:Any, Int}`, on Julia 1.3 and later ([#300](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/300), [#297](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/297))
- Fix `TYPEDSIGNATURES` leaving out the return type of a callable such as `(e::E)(x)` and of a constructor written `T{P}(...)`. Before Julia 1.6 they still print without one ([#279](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/279), [#296](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/296))
- Fix a wrapped signature with only keyword arguments printing `;` alone on its own line. It prints `f(;` on the first line. A signature without arguments no longer wraps, so a long return type follows `f()` ([#281](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/281), [#295](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/295))
- Fix `METHODLIST` and `TYPEDMETHODLIST` in a parametric type's docstring leaving out the constructors written `T{P}(...)` ([#280](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/280), [#294](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/294))
- Fix signatures printing a `where` bound that names another type parameter with `Array{T, 1}` where the source writes `Vector{T}`, such as `S<:Vector{T}` ([#278](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/278), [#293](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/293))
- Fix a world-age warning on Julia 1.12 and later when `@template` and a docstring expand together from running code, such as in one `macroexpand` call. Under `--depwarn=error` the docstring lost its template ([#277](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/277), [#292](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/292))
- Fix `@template` skipping a docstring on a bare existing name, such as `"..." f` after `function f end`. The dotted form `"..." M.f` already got its template ([#276](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/276), [#291](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/291))
- Fix a templated docstring on a name that is never defined throwing an `UndefVarError` when it renders. It gets the `DEFAULT` template ([#275](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/275), [#290](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/290))
- Fix `@template` giving a method defined through a `const` alias, such as `const Point2 = Point{2}` then `Point2(x) = ...`, the `CONSTANTS` template where it should get `METHODS` ([#274](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/274), [#289](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/289))
- Fix `@template` not applying to a docstring in the same `begin` block as the `@template` ([#273](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/273), [#288](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/288))
- Fix `IMPORTS` crashing or hanging Julia in the docstring of anything but a module. It throws a `TypeError` instead, as `EXPORTS` does ([#283](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/283), [#287](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/287))
- Fix `TYPEDEF` leaving out the parameters of a parametric primitive type, and printing a `Symbol` or `Char` parameter unquoted, such as `Val{a}` for `Val{:a}` ([#271](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/271), [#272](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/272), [#286](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/286))
- Fix `SUBTYPES` listing a subtype once more for each `const` that names its module ([#270](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/270), [#285](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/285))
- Fix `EXPORTS` listing no names on Julia 1.12 and later when a docstring renders in a world older than its module ([#282](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/282), [#284](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/284))
- Fix `@template` throwing a `MethodError` for a docstring on a parametric `Union` alias, such as `const Maybe{T} = Union{T,Nothing}`. The alias gets the `CONSTANTS` template ([#242](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/242))
- Fix `defaults = true` signatures printing the source file and line before a default value that contains a macro call ([#238](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/238))
- Fix `EXPORTS` listing names declared `public` but not exported on Julia 1.11 and later ([#190](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/190))
- Fix two error messages printing the text `typeof(...)` where they should name a type: the one for an object with no `format` method, and the one for an unexpected `TYPEDSIGNATURES` signature type ([#216](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/216))
- `METHODLIST` and `TYPEDMETHODLIST` show each file relative to its package root, such as `src/shapes.jl`. A package loaded from a development checkout, as in every Documenter build, showed the checkout's absolute path ([#217](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/217))
- Fix `TYPEDSIGNATURES` and `TYPEDMETHODLIST` printing the return type of another method when a more specific method's signature overlaps the documented one ([#218](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/218))
- Fix `TYPEDSIGNATURES` failing on Julia 1.0 and 1.10 when a `@generated` method overlaps the documented one. The signature now prints without a return type, as it does for a documented `@generated` method ([#222](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/222))
- Fix a docstring on a parametric type's constructor, such as `Point(x::T) where {T}` inside `struct Point{T}`, getting the `DEFAULT` template where it should get `METHODS` ([#226](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/226))
- Fix `TYPEDSIGNATURES` and `TYPEDMETHODLIST` printing a vararg argument as `xs::Vararg{T,N} where N` before Julia 1.5. They print `xs::T...`, as on later versions ([#228](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/228))
- Fix `TYPEDSIGNATURES` and `TYPEDMETHODLIST` on a fixed-count vararg such as `xs::Vararg{Int,2}`, which they print as `xs::Vararg{Int64, 2}`. `TYPEDSIGNATURES` printed the whole signature without types, and `TYPEDMETHODLIST` printed `xs::Int64` or dropped `xs`. With a type parameter as the element type, both dropped the count ([#229](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/229))
- `TYPEDSIGNATURES` and `TYPEDMETHODLIST` keep a method's type parameters by name and declare them in a `where` clause, as Julia prints a method: `f(x::T, xs::T...) where {T <: Number}` gives `f(x::T, xs::T...) where T<:Number`. They replaced each parameter with its bound, and wrote it as `T<:Number` inside a type such as `Vector{T<:Number}` or a vararg ([#109](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/109), [#230](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/230))
- Fix `SIGNATURES` and `TYPEDSIGNATURES` printing nothing on Julia 1.12 and later for a parametric definition with a positional default before a vararg, such as `f(x::T = 1, xs::T...) where {T}` ([#231](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/231))
- Fix `TYPEDSIGNATURES` printing a type parameter with a lower bound as that bound: `f(x::T) where {Int8 <: T <: Integer}` gave `f(x::Int8)`. It prints `f(x::T) where Int8<:T<:Integer` ([#232](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/232))
- Fix `SIGNATURES` and `TYPEDSIGNATURES` on a constructor written with type parameters, such as `Point{T}() where {T}`. They described the type's default constructor, as `Point(x)`, and print `Point{T}()` and `Point{T}() where T`. Both now print only the definition the docstring is written on ([#164](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/164), [#234](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/234))
- Fix `SIGNATURES` and `TYPEDSIGNATURES` printing nothing on Julia 1.14 for a method with a bounded type parameter, such as `f(x::Vector{T}) where {T <: Number}`, and printing a constructor written as `T{P}(...)` without its parameters ([#236](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/236))
- Fix `SIGNATURES` and `TYPEDSIGNATURES` on a constructor that writes fewer type parameters than its type has, such as `D{T}(g) where {T}` for `struct D{T,MM}`. Its own docstring printed nothing, or another constructor of the type defined earlier in the file, and the struct's docstring left it out. A call through an alias that writes some of the alias's parameters, such as `Mat{Int}(a)` for `const Mat{T,B} = Arr{T,2,B}`, prints as `Mat{Int64}(a)` ([#255](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/255), [#260](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/260))
- Fix `SIGNATURES` and `TYPEDSIGNATURES` on a callable method of a type, such as `(e::E)(σ)`. They printed a constructor of `E` that takes as many arguments, or nothing. They print `(e::E)(σ)`, with `(::E)` for an unnamed instance. A callable on `Type`, such as `(::Type{<:D})(n)`, prints the type it is called on ([#256](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/256), [#261](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/261))
- Fix the printing of a type parameter written `<:T` or `>:T` in signatures, where it showed the name Julia generates. Before Julia 1.7, `x::Ref{<:Real}` printed as `x::Ref{var"#s1"} where var"#s1"<:Real`, and Julia 1.14 prints `Type{<:T}` that way. Signatures now print the parameter as written on every version ([#261](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/261))
- Fix `TYPEDFIELDS` and `TYPEDEF` printing a type parameter written `<:T` or `>:T` as the name Julia generates. Before Julia 1.7 a field `x::Ref{<:Real}` printed as `x::Ref{var"#s1"} where var"#s1"<:Real`, as did a bound such as `struct P{T<:Ref{<:Real}}` and a parameter of the supertype. Julia 1.14 prints a field of type `Type{<:T}` that way. Fields and type definitions now print the parameter as written on every version, and `Ref{<:Any}` as `Ref`. A `const` alias applied to `<:T`, such as `ScalarOrVec{<:AbstractFloat}` for `const ScalarOrVec{T} = Union{T, AbstractVector{T}} where T`, prints as that alias in signatures, fields and type definitions, on every version. DSE looks for the alias in the module that defines the documented object, in its parent modules, among the names it imports, and in the modules of the types it names. A type no alias gives prints as `show` prints it, and an inferred return type that would show a generated name is left out. `TYPEDEF` prints a supertype and each parameter's bound with the type's own parameters by name, as in `struct Leap{T<:Real} <: AbstractLeap{T}` and `struct Extended{N<:Number, T<:Ref{N}}`. It repeated each bound there and wrote `Array{T, 1}` for `Vector{T}`. A bound in a type definition or a `where` clause is in parentheses only when it holds a `where` of its own ([#264](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/264))
- Fix `@template` giving a function named like a macro, such as `var"@f"(a) = a`, the `MACROS` template. A docstring gets `MACROS` only when it documents a macro ([#263](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/263))
- Fix abbreviations failing to find methods and bindings on Julia 1.12, where `format` runs in a stale world age. Method and binding lookups now go through `Base.invokelatest` ([#185](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/185))
- `TYPEDSIGNATURES` prints a method's own argument types when no type signature in the docstring matches it. It used to throw an `ArgumentError`. On Julia 1.12 and later this covers a definition such as `f(x = 1, xs...)` ([#185](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/185), [#225](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/225))
- Fix `SIGNATURES` and `TYPEDSIGNATURES` printing nothing on Julia 1.12 and later for a definition with a positional default before a vararg, such as `f(x = 1, xs...)` ([#193](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/193))
- Fix unnamed arguments printing as an empty name, or as `#temp#` before Julia 1.4. `SIGNATURES` prints them as `_`, and `TYPEDSIGNATURES` as `::T` ([#193](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/193))
- `@template MODULES = ModName` throws an `ArgumentError` naming the module and category when `ModName` defines no such template, including a module naming itself, where it threw a bare `KeyError` or `UndefVarError` ([#117](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/117), [#212](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/212))
- `SIGNATURES` and `TYPEDSIGNATURES` print a destructured argument as the definition writes it, such as `f((a, b))`, where they printed `_` ([#67](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/67), [#204](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/204))
- Fix `SIGNATURES` and `TYPEDSIGNATURES` ending their code block with an empty line, which left two blank lines before the text that follows it in the REPL ([#214](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/214))
- Fix `SIGNATURES` leaving out the `...` after a vararg ([#193](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/193))
- Fix objects interpolated into an `@template` never receiving the documented expression from `interpolation` ([#194](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/194))
- Fix `TYPEDSIGNATURES` throwing for a `@generated` method with abstract argument types on Julia 1.0 and 1.10. It now leaves out the return type, which inference could only give as `Any` ([#157](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/157))
- Fix `@template` skipping docstrings documented through the five-argument `@doc` form, which passes a `define` flag. Templates now apply to docstrings that Revise re-evaluates ([#207](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/207), [#209](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/209))

## [v0.9.5](https://github.com/JuliaDocs/DocStringExtensions.jl/releases/tag/v0.9.5) - 2025-06-06

### Fixed

- Fix keyword argument lookup on Julia nightly, where `methods(f).mt` no longer exists ([#176](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/176))

## [v0.9.4](https://github.com/JuliaDocs/DocStringExtensions.jl/releases/tag/v0.9.4) - 2025-03-28

### Added

- Add the `interpolation(object, expr)` hook, so an object interpolated into a docstring can see the expression being documented ([#133](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/133))

### Changed

- Remove the `LibGit2` dependency. `METHODLIST` source links come from `Base.url` and no longer read the package's git remote, unless the `TRAVIS_*` environment variables are set ([#172](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/172))
- Clarify the `@template` docstring ([#152](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/152))

### Fixed

- Fix tests on Julia 1.10 and later ([#168](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/168))

## [v0.9.3](https://github.com/JuliaDocs/DocStringExtensions.jl/releases/tag/v0.9.3) - 2022-12-08

### Fixed

- Fix field descriptions in `FIELDS` and `TYPEDFIELDS` starting on a new line, a regression in v0.9.2 ([#139](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/139))
- Fix `SIGNATURES` and `TYPEDSIGNATURES` leaving out methods whose signatures have `where` type parameters ([#102](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/102), [#141](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/141))

## [v0.9.2](https://github.com/JuliaDocs/DocStringExtensions.jl/releases/tag/v0.9.2) - 2022-10-21

### Changed

- Condense `FIELDS` and `TYPEDFIELDS` output by putting each field's description on the same line as its name, after a colon ([#63](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/63), [#136](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/136))

### Fixed

- Fix keyword argument handling on Julia master and filter a new internal symbol out of argument lists ([#137](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/137))
- Fix `TYPEDSIGNATURES` choosing the wrong signature on Windows with Julia 1.8 and later ([#138](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/138))

## [v0.9.1](https://github.com/JuliaDocs/DocStringExtensions.jl/releases/tag/v0.9.1) - 2022-07-26

### Fixed

- Fix argument name extraction for generated functions ([#126](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/126), [#131](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/131))
- Fix the `TYPES` template not applying to parametric types ([#115](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/115), [#132](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/132))

## [v0.9.0](https://github.com/JuliaDocs/DocStringExtensions.jl/releases/tag/v0.9.0) - 2022-05-26

### Changed

- Break long signatures over multiple lines ([#120](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/120), [#128](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/128))

## [v0.8.6](https://github.com/JuliaDocs/DocStringExtensions.jl/releases/tag/v0.8.6) - 2021-10-25

### Changed

- `TYPEDSIGNATURES` prints a constrained type parameter as its bound, such as `y::Number` instead of `y::T<:Number`, and leaves an unconstrained one untyped ([#125](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/125))

### Fixed

- Fix `TYPEDSIGNATURES` for methods such as `f(x::T) where T`, and fix tests on Julia 1.8 ([#124](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/124), [#125](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/125))

## [v0.8.5](https://github.com/JuliaDocs/DocStringExtensions.jl/releases/tag/v0.8.5) - 2021-06-09

### Removed

- Drop support for Julia 0.7 ([#114](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/114))

### Fixed

- Fix loading on Julia 1.7, which removed the `DataType.abstract` and `DataType.mutable` fields ([#116](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/116))
- Fix `Vararg` arguments printing without `...` ([#46](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/46), [#113](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/113))

## [v0.8.4](https://github.com/JuliaDocs/DocStringExtensions.jl/releases/tag/v0.8.4) - 2021-03-23

### Fixed

- Fix `TYPEDEF` omitting type parameters of abstract types ([#104](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/104), [#105](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/105))

## [v0.8.3](https://github.com/JuliaDocs/DocStringExtensions.jl/releases/tag/v0.8.3) - 2020-08-27

### Fixed

- `@template` now expands templates at format time instead of definition time. This fixes templates on definitions documented through `Base.@__doc__`, and a `TYPEDSIGNATURES` error on Julia master ([#73](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/73), [#93](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/93), [#96](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/96))

## [v0.8.2](https://github.com/JuliaDocs/DocStringExtensions.jl/releases/tag/v0.8.2) - 2020-06-15

### Changed

- Print unnamed arguments as `_` ([#91](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/91))

### Fixed

- Fix `TYPEDSIGNATURES` for methods with several type parameters or `Union` arguments ([#84](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/84), [#87](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/87), [#88](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/88))

## [v0.8.1](https://github.com/JuliaDocs/DocStringExtensions.jl/releases/tag/v0.8.1) - 2019-10-08

### Fixed

- Fix the call to the internal `Base.kwarg_decl` on Julia 1.4 ([#82](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/82), [#83](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/83))

## [v0.8.0](https://github.com/JuliaDocs/DocStringExtensions.jl/releases/tag/v0.8.0) - 2019-06-22

### Added

- Add the `TYPEDFIELDS` abbreviation, which lists fields with their types and docstrings ([#75](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/75), [#77](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/77))

### Changed

- Restrict Julia compat to 0.7 and 1.x ([#80](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/80))

## [v0.7.0](https://github.com/JuliaDocs/DocStringExtensions.jl/releases/tag/v0.7.0) - 2019-03-11

### Added

- Add the `TYPEDSIGNATURES` abbreviation, which expands into typed method signatures ([#20](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/20), [#72](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/72))

## [v0.6.0](https://github.com/JuliaDocs/DocStringExtensions.jl/releases/tag/v0.6.0) - 2018-11-23

### Added

- Add the `README` and `LICENSE` abbreviations ([#68](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/68))

### Fixed

- Fix tests when the package is not inside a git repository ([#70](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/70))

## [v0.5.0](https://github.com/JuliaDocs/DocStringExtensions.jl/releases/tag/v0.5.0) - 2018-08-29

### Added

- Add the `FUNCTIONNAME` abbreviation ([#59](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/59), [#66](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/66))

### Removed

- Drop support for Julia 0.6 ([#65](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/65))

## [v0.4.6](https://github.com/JuliaDocs/DocStringExtensions.jl/releases/tag/v0.4.6) - 2018-08-11

### Changed

- `TYPEDEF` prints Julia 0.7 and 1.0 type syntax (`mutable struct`, `abstract type`, `primitive type`) ([#64](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/64))

## [v0.4.5](https://github.com/JuliaDocs/DocStringExtensions.jl/releases/tag/v0.4.5) - 2018-07-03

### Fixed

- Adapt source path cleaning to Pkg3 and use `Core.eval` ([#60](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/60))

## [v0.4.4](https://github.com/JuliaDocs/DocStringExtensions.jl/releases/tag/v0.4.4) - 2018-03-28

### Fixed

- Fix deprecations on Julia 0.7-dev ([#53](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/53), [#55](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/55), [#57](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/57))

## [v0.4.3](https://github.com/JuliaDocs/DocStringExtensions.jl/releases/tag/v0.4.3) - 2018-01-19

### Fixed

- Fix a loop variable conflict on Julia 0.7-dev ([#50](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/50))

## [v0.4.2](https://github.com/JuliaDocs/DocStringExtensions.jl/releases/tag/v0.4.2) - 2018-01-18

### Fixed

- Fix deprecations and `findfirst` returning `nothing` on Julia 0.7-dev ([#48](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/48))

## [v0.4.1](https://github.com/JuliaDocs/DocStringExtensions.jl/releases/tag/v0.4.1) - 2017-09-21

### Fixed

- Fix deprecation warnings ([#43](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/43))
- Fix keyword arguments of methods with `UnionAll` signatures ([#44](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/44))

## [v0.4.0](https://github.com/JuliaDocs/DocStringExtensions.jl/releases/tag/v0.4.0) - 2017-08-13

### Removed

- Drop support for Julia 0.4 and 0.5 ([#36](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/36))

### Fixed

- Fix `SIGNATURES` for methods with `UnionAll` arguments, and `@template` for method definitions with `where` clauses ([#32](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/32), [#38](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/38))
- Fix `@template` for types on Julia 0.7, where the `struct` and `primitive` expression heads replaced `type` and `bitstype` ([#37](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/37))
- Fix deprecation warnings ([#36](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/36), [#40](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/40))

## [v0.3.4](https://github.com/JuliaDocs/DocStringExtensions.jl/releases/tag/v0.3.4) - 2017-07-25

### Fixed

- Fix compatibility with Julia 0.7 ([#33](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/33))

## [v0.3.3](https://github.com/JuliaDocs/DocStringExtensions.jl/releases/tag/v0.3.3) - 2017-03-27

### Fixed

- Update type declaration syntax for Julia 0.6 to remove deprecation warnings ([#28](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/28))

## [v0.3.2](https://github.com/JuliaDocs/DocStringExtensions.jl/releases/tag/v0.3.2) - 2017-03-27

### Fixed

- Fix method introspection on Julia 0.6 ([#27](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/27))

## [v0.3.1](https://github.com/JuliaDocs/DocStringExtensions.jl/releases/tag/v0.3.1) - 2016-12-15

### Fixed

- Fix method and type introspection for the new `UnionAll` type representation on Julia 0.6 ([#25](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/25))

## [v0.3.0](https://github.com/JuliaDocs/DocStringExtensions.jl/releases/tag/v0.3.0) - 2016-11-21

### Added

- Add docstring templates with `@template` ([#23](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/23))
- Add the `DOCSTRING` abbreviation for use in templates ([#23](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/23))

### Fixed

- Fix `takebuf_string` deprecations ([#23](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/23))

## [v0.2.1](https://github.com/JuliaDocs/DocStringExtensions.jl/releases/tag/v0.2.1) - 2016-09-14

### Added

- Add the `TYPEDEF` abbreviation ([#18](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/18))

### Fixed

- Fix compatibility with the removal of `LambdaInfo` on Julia 0.6 ([#21](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/21))

## [v0.2.0](https://github.com/JuliaDocs/DocStringExtensions.jl/releases/tag/v0.2.0) - 2016-08-21

### Changed

- Remove automatic headers from abbreviation output ([#9](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/9), [#11](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/11))

### Fixed

- Deduplicate methods in `METHODLIST` and `SIGNATURES` ([#14](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/14), [#15](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/15))

## [v0.1.0](https://github.com/JuliaDocs/DocStringExtensions.jl/releases/tag/v0.1.0) - 2016-08-02

Initial release.
