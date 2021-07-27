```@meta
CurrentModule = ExtensibleEffects
```

# ExtensibleEffects

Documentation for [ExtensibleEffects](https://github.com/JuliaFunctional/ExtensibleEffects.jl).

This package provides an implementation of Extensible Effects. We follow the approach presented in the paper [Freer Monads, More Extensible Effects](http://okmij.org/ftp/Haskell/extensible/more.pdf) which already has an [Haskell implementation](https://hackage.haskell.org/package/freer-effects) as well as a [Scala implementation](https://github.com/atnos-org/eff).

This Julia implementation is massively simplified, and hence can also serve as a good introduction to get to know the details behind Extensible Effects.

Many effects are provided, ranging from `Option`, which can be handled very simple, to the very limit of what can be supported by ExtensibleEffects - the `State` effect. Still, all the implementations are short and easy to follow, so look into the `instances.jl` file to see how to write your own Effect handlings.

## Presentation at JuliaCon 2021

The package was presented at JuliaCon 2021.
* find the video [at youtube](TODO)
* find the presentation in this binder [![Binder](https://mybinder.org/badge_logo.svg)](https://mybinder.org/v2/gh/JuliaFunctional/ExtensibleEffects.jl/main?filepath=docs%2Fjupyter%2FMonad2.0%2C%20aka%20Algebraic%20Effects%20-%20ExtensibleEffects.jl.ipynb). The binder link provides you with a Jupyter environment where you can actually run julia code and explore the ExtensibleEffects further. The link will autostart into the presentation itself, clicking the big X on the top left will exit the presentation mode and bring you to a standard Jupyter notebook.

## Manual Outline

```@contents
Pages = ["manual-introduction.md", "manual-effects.md", "manual-how-it-works.md", "manual-juliacon.md"]
```

## [Library Index](@id main-index)

```@index
Pages = ["library.md"]
```