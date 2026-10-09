# DocStringExtensions.jl changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Added

- Add `TypedMethodSignatures(false)`, which renders typed signatures without return types ([#159](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/159), [#179](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/179))

### Fixed

- Fix abbreviations failing to find methods and bindings on Julia 1.12, where `format` runs in a stale world age. Method and binding lookups now go through `Base.invokelatest` ([#185](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/185))
- Fix tests on Julia 1.12 ([#178](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/178))

## [v0.9.5](https://github.com/JuliaDocs/DocStringExtensions.jl/releases/tag/v0.9.5) - 2025-06-06

### Fixed

- Fix failures on Julia nightly ([#176](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/176))

## [v0.9.4](https://github.com/JuliaDocs/DocStringExtensions.jl/releases/tag/v0.9.4) - 2025-03-28

### Added

- Support capturing `Expr` values for use in abbreviations ([#133](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/133))

### Changed

- Remove the `LibGit2` dependency ([#172](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/172))
- Clarify the `@template` docstring ([#152](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/152))

### Fixed

- Fix tests on Julia 1.10 and later ([#168](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/168))

## [v0.9.3](https://github.com/JuliaDocs/DocStringExtensions.jl/releases/tag/v0.9.3) - 2022-12-08

### Fixed

- Fix an extra newline before field descriptions in `FIELDS` and `TYPEDFIELDS` ([#139](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/139))
- Fix broadcasting over `Base.rewrap_unionall` when collecting all type signatures, which made `SIGNATURES` output nondeterministic ([#102](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/102), [#141](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/141))

## [v0.9.2](https://github.com/JuliaDocs/DocStringExtensions.jl/releases/tag/v0.9.2) - 2022-10-21

### Changed

- Condense `FIELDS` and `TYPEDFIELDS` output by removing the blank line after each field name ([#63](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/63), [#136](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/136))

### Fixed

- Fix keyword argument handling on Julia master and filter a new internal symbol out of argument lists ([#137](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/137))
- Fix argument ordering on newer Windows versions ([#138](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/138))

## [v0.9.1](https://github.com/JuliaDocs/DocStringExtensions.jl/releases/tag/v0.9.1) - 2022-07-26

### Fixed

- Fix argument name extraction for generated functions ([#126](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/126), [#131](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/131))
- Fix the `TYPES` template not applying to parametric types ([#115](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/115), [#132](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/132))

## [v0.9.0](https://github.com/JuliaDocs/DocStringExtensions.jl/releases/tag/v0.9.0) - 2022-05-26

### Changed

- Break long signatures over multiple lines ([#120](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/120), [#128](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/128))

## [v0.8.6](https://github.com/JuliaDocs/DocStringExtensions.jl/releases/tag/v0.8.6) - 2021-10-25

### Fixed

- Fix test failures on Julia 1.8 and improve printing of parametric types ([#124](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/124), [#125](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/125))

## [v0.8.5](https://github.com/JuliaDocs/DocStringExtensions.jl/releases/tag/v0.8.5) - 2021-06-09

### Changed

- Move test dependencies out of `[deps]` ([#114](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/114))
- Remove internal `isabstracttype` and `isbitstype` definitions ([#116](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/116))

### Fixed

- Fix `Vararg` arguments printing without `...` ([#46](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/46), [#113](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/113))

## [v0.8.4](https://github.com/JuliaDocs/DocStringExtensions.jl/releases/tag/v0.8.4) - 2021-03-23

### Fixed

- Fix `TYPEDEF` omitting type parameters of abstract types ([#104](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/104), [#105](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/105))
- Fix tests on Julia 1.6 and later ([#106](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/106))

## [v0.8.3](https://github.com/JuliaDocs/DocStringExtensions.jl/releases/tag/v0.8.3) - 2020-08-27

### Fixed

- `@template` now expands templates at format time instead of definition time. This fixes templates with `Base.@__doc__` and `@kwdef` structs, and a `TYPEDSIGNATURES` error on Julia master ([#73](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/73), [#93](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/93), [#98](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/98), [#96](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/96))

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

- Put an upper bound on the compatible Julia version ([#80](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/80))

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

### Fixed

- Update signature handling for Julia 0.7 and 1.0 ([#64](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/64))

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

- Fix `SIGNATURES` for methods with `UnionAll` arguments ([#38](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/38))
- Fix deprecation warnings ([#37](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/37), [#40](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/40))

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

- Fix subtype introspection on Julia 0.6 ([#25](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/25))

## [v0.3.0](https://github.com/JuliaDocs/DocStringExtensions.jl/releases/tag/v0.3.0) - 2016-11-21

### Added

- Add docstring templates with `@template` ([#23](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/23))

### Fixed

- Fix `takebuf_string` deprecations

## [v0.2.1](https://github.com/JuliaDocs/DocStringExtensions.jl/releases/tag/v0.2.1) - 2016-09-14

### Added

- Add the `TYPEDEF` abbreviation ([#18](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/18))

### Fixed

- Fix compatibility with the removal of `LambdaInfo` on Julia 0.6 ([#21](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/21))

## [v0.2.0](https://github.com/JuliaDocs/DocStringExtensions.jl/releases/tag/v0.2.0) - 2016-08-21

### Changed

- Remove automatic headers from abbreviation output ([#9](https://github.com/JuliaDocs/DocStringExtensions.jl/issues/9), [#11](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/11))

### Fixed

- Deduplicate methods in `METHODLIST` ([#15](https://github.com/JuliaDocs/DocStringExtensions.jl/pull/15))

## [v0.1.0](https://github.com/JuliaDocs/DocStringExtensions.jl/releases/tag/v0.1.0) - 2016-08-02

Initial release.
