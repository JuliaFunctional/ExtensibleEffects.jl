```@meta
CurrentModule = ExtensibleEffects
DocTestSetup  = quote
    using ExtensibleEffects
end
```

# Introduction

Welcome to `ExtensibleEffects.jl`. This package provides an implementation of Extensible Effects. We follow the approach presented in the paper [Freer Monads, More Extensible Effects](http://okmij.org/ftp/Haskell/extensible/more.pdf) which already has an [Haskell implementation](https://hackage.haskell.org/package/freer-effects) as well as a [Scala implementation](https://github.com/atnos-org/eff).

This Julia implementation is massively simplified, and hence can also serve as a good introduction to get to know the details behind Extensible Effects.

Many effects are provided, ranging from `Option`, which can be handled very simple, to the very limit of what can be supported by ExtensibleEffects - the `State` effect. Still, all the implementations are short and easy to follow, so look into the `instances.jl` file to see how to write your own Effect handlings.

## Installation

```julia
using Pkg
pkg"add ExtensibleEffects"
```

Use it like

```julia
using ExtensibleEffects
```

## Usage

The power of ExtensibleEffects.jl is to combine multiple different contexts into one *composable* super context abstraction. Its key macro is 
```julia
@syntax_eff begin
  a = an_effect
  b = another_effect
  @pure a, b
end
```
which provides a syntax similar to `TypeClasses.@syntax_flatmap` for working seamlessly with effects. See its documentation [`@syntax_eff`](@ref) for more details.

There is another version of the key macro called [`@syntax_eff_noautorun`](@ref), which as the name indicates disables the autorun feature of `@syntax_eff`. You may need this in case you don't want to execute your effects immediately, but staying in the meta-monad `ExtensibleEffects.Eff` for further composition with other effectful algorithms. [Effects](@ref) and [How does it actually work?](@ref) also provide some examples of using `@syntax_eff_noautorun` for explanation purposes.

You can also specifically disable the autorun feature for individual effects only by using the [`noautorun`](@ref) function like
```julia
@syntax_eff noautorun(Vector) begin
  ...
end
```
which in this case would not handle the `Vector` effect.

----------------------

In addition to `@syntax_eff`, `@syntax_eff_noautorun` and `@syntax_eff noautorun(effect1, effect2, ...)` the package reexports all **data types** from [`DataTypesBasic.jl`](https://github.com/JuliaFunctional/DataTypesBasic.jl) and [`TypeClasses.jl`](https://github.com/JuliaFunctional/TypeClasses.jl)

For the more complicated effects `Writer`, `Callable`, `ContextManager` and `State` extra handlers and further helper macros are provided. Take a look at [Example](@ref) and [Effects](@ref) for further details. 


## Example

To start small, you can use `ExtensibleEffects.@syntax_eff` instead of `TypeClasses.@syntax_flatmap`.

```jldoctest
julia> @syntax_eff begin
         a = [1, 2]
         b = ["one", "two"]
         @pure a, b
       end
4-element Vector{Tuple{Int64, String}}:
 (1, "one")
 (1, "two")
 (2, "one")
 (2, "two")

julia> option_example(n) = @syntax_eff begin
         a = Option(n)
         b = @Try isodd(a) ? error("fail") : a+1
         @pure a, b
       end
option_example (generic function with 1 method)

julia> option_example(nothing)
Const(nothing)

julia> option_example(41)
Const(Thrown(ErrorException("fail")))

julia> option_example(42)
Identity((42, 43))
```

Some monads of TypeClasses need a bit more work to translate them into effects. They need little extra wrappers, but nothing fancy, just use their respective `@run...` macro.

Let's directly jump to super complicated interactions of many effects at once. Please experiment with this little example. Take effects out, reorder them, etc.

```jldoctest
julia> # simple ContextManager for example purposes
       create_context(x) = @ContextManager continuation -> begin
         println("before $x")
         result = continuation(x)
         println("after $x")
         result
       end
create_context (generic function with 1 method)

julia> contextmanager_callable_state = @runcontextmanager @runcallable @runstate @syntax_eff begin
         co = create_context(4)
         ve = collect(1:co)
         st = State(s -> (ve+s, 2s))
         op = isodd(st) ? Option(100) : Option()
         ca = Callable(x -> "x = $x, st = $st, op = $op")
         @pure [co, ve, st, op, ca]
       end;

julia> # running the contextmanager
       result, nextstate = run(contextmanager_callable_state) do value
         @show value  
       end |>
       # calling the callable
       callable_state -> callable_state("hello") |>
       # providing initial state for the state
       state -> run(state, 11);
before 4
value = (Option{Vector{Any}}[Const(nothing), Const(nothing), Identity(Any[4, 3, 47, 100, "x = hello, st = 47, op = 100"]), Const(nothing)], 176)
after 4

julia> result
4-element Vector{Option{Vector{Any}}}:
 Const(nothing)
 Const(nothing)
 Identity(Any[4, 3, 47, 100, "x = hello, st = 47, op = 100"])
 Const(nothing)

julia> nextstate
176
```

Welcome to fully composable effects. [Effects](@ref) and [How does it actually work?](@ref) can provide you more details.


## Core Interface `eff_applies`, `eff_pure`, `eff_flatmap`

All effects and effect handlers need to overwrite the three core functions. We specify them by using `Vector` as an example:


| core function                                                    | default                                                                                              | description                                                                                                                                                                                                                                                                                                                                                     |
| ------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `eff_applies(handler::Type{<:Vector}, effectful::Vector) = true` | there is no default                                                                                  | specify on which values the handler applies (the handler Vector applies to Vector of course)                                                                                                                                                                                                                                                                    |
| `eff_pure(handler::Type{<:Vector}, value) = [value]`             | defaulting to `TypeClasses.pure` (enough for Vector)                                                  | wrap a plain value into the Monad of the handler, here Vector.                                                                                                                                                                                                                                                                                                  |
| `eff_flatmap(continuation, effectful::Vector)`                   | defaults to using `map`, `flatmap`, and `flip_types` from `TypeClasses` (this is enough for `Vector`) | apply a continuation to the current effect (here again Vector as an example). The key difference to plain`TypeClasses.flatmap` is that `continuation` does not return a plain `Vector`, but a `Eff{Vector}`. Applying this `continuation` with a plain `map` would lead `Vector{Eff{Vector}}`. However, `eff_flatmap` needs to return an `Eff{Vector}` instead. |


## Future Work

Julia's type-inference seems to have quite some trouble inferring through the core algorithms of ExtensibleEffects. Hence in case type-inference and speed is crucial to your effectful/monadic code, we recommend to use [`TypeClasses.jl`](https://github.com/JuliaFunctional/TypeClasses.jl) as of now. The monads of TypeClasses.jl do not compose that well as the effects in ExtensibleEffects.jl, but type-inference is much simpler.