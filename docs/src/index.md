```@meta
CurrentModule = ExtensibleEffects
```

# ExtensibleEffects

Documentation for [ExtensibleEffects](https://github.com/JuliaFunctional/ExtensibleEffects.jl).

This package provides an implementation of Extensible Effects. One concrete approach was presented in the paper [Freer Monads, More Extensible Effects](http://okmij.org/ftp/Haskell/extensible/more.pdf) which already has an [Haskell implementation](https://hackage.haskell.org/package/freer-effects) as well as a [Scala implementation](https://github.com/atnos-org/eff).

This Julia implementation is massively simplified, and hence can also serve as a good introduction to get to know the details behind Extensible Effects.

Many effects are provided, ranging from `Option`, which can be handled very simple, to the very limit of what can be supported by ExtensibleEffects - the `State` effect. Still, all the implementations are short and easy to follow, so look into the `instances.jl` file to see how to write your own Effect handlings.

## Manual Outline

```@contents
Pages = ["manual.md"]
```

## [Library Index](@id main-index)

```@index
Pages = ["library.md"]
```