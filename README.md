# ExtensibleEffects

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://JuliaFunctional.github.io/ExtensibleEffects.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://JuliaFunctional.github.io/ExtensibleEffects.jl/dev)
[![Build Status](https://github.com/JuliaFunctional/ExtensibleEffects.jl/workflows/CI/badge.svg)](https://github.com/JuliaFunctional/ExtensibleEffects.jl/actions)
[![Coverage](https://img.shields.io/codecov/c/github/JuliaFunctional/ExtensibleEffects.jl)](https://codecov.io/gh/JuliaFunctional/ExtensibleEffects.jl)

This package provides an implementation of Extensible Effects. We follow the approach presented in the paper [Freer Monads, More Extensible Effects](http://okmij.org/ftp/Haskell/extensible/more.pdf) which already has an [Haskell implementation](https://hackage.haskell.org/package/freer-effects) as well as a [Scala implementation](https://github.com/atnos-org/eff).

This Julia implementation is massively simplified, and hence can also serve as a good introduction to get to know the details behind Extensible Effects.

Many effects are provided, ranging from `Option`, which can be handled very simple, to the very limit of what can be supported by ExtensibleEffects - the `State` effect. Still, all the implementations are short and easy to follow, so look into the `instances.jl` file to see how to write your own Effect handlings.