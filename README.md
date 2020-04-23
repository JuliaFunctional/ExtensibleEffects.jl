# Extensible Effects

This package provides an implementation of Extensible Effects. One concrete approach was presented in the paper [Freer Monads, More Extensible Effects](http://okmij.org/ftp/Haskell/extensible/more.pdf) which already has an [Haskell implementation](https://hackage.haskell.org/package/freer-effects) as well as a [Scala implementation](https://github.com/atnos-org/eff).

This Julia implementation is massively simplified, and hence can also serve as a good introduction to get to know the details behind Extensible Effects.

This package provides effects ranging from `Option`, which can be handled very simple, to the very limit of what can be supported by ExtensibleEffects - the `State` effect. Still, all the implementations are short and easy to follow, so look into the `instances.jl` file to see how to write your own Effect handlings.

# eff_applies, eff_pure, eff_flatmap

`Option`, `Vector`, `Iterable` and many more are handled by overwriting the three core functions. We specify them by using Vector as an example:

core function | description
------------- | ------------
`eff_applies(handler::Type{<:Vector}, value::Vector) = true` | specify on which values the handler applies (the handler Vector applies to Vector of course)
`eff_pure(handler::Type{<:Vector}, value) = [value]` | wrap a plain value into the Monad of the handler, here Vector.
`eff_flatmap(continuation, value::Vector)` | apply a continuation to the current effect (here again Vector as an example)

TODO show at least the implementation of one example, say Option.

# More Complex ExtensibleEffect Handlers

While `Option`, `Try`, `ContextManager`, and the like, have almost trivial implementations, `Vector`, `Iterable`, and `Writer` need a bit more interaction with the effect system.

TODO add implementation example

All these can still be run automatically, without any further context parameters. In ExtensibleEffect terms, this means that `Option`, `Vector`, `Iterable` and the like are handlers by its own.
We acknowledge this everytime we define `eff_applies` like such `ExtensibleEffects.eff_applies(handler::Type{<:HandlerType}, value::HandlerType) = true`.

# Handlers With Additional Parameters
TODO Writer example

The background story, why we need this and cannot directly work on `Callable` itself, is that within the ExtensibleEffects framework, effects always need to be transform to `noeffect`, which is just the Identity Monad effect. This means we have to able to work on plain values, and cannot work on opaque Functors. See the [Limitations section](#limitations) for further details on this.

# Handlers which need to be updated from one effect to another

TODO State example  (without outer handling)
The most advanced possibility to define effects is showcased by `State`. It needs a custom handler which provides the initial state information `StateHandler(state)`, similar to `Callable`. In addition, every effect actually adapts the state, and hence the handler itself must be updated accordingly so that subsequent effects are actually handled with the correct current state. This can be done by implementing a


# Outer Handlers
To evaluate a `Callable` we need `args` and `kwargs`, hence there is also a custom handler `CallableHandler(args...; kwargs...)` to run `Callable` effects. We can just run it using explicit `args`, `kwargs`, but we can also reconstruct a true Callable.

TODO show how to reconstruct Callable manualle
```julia
Callable(function (args...; kwargs...)
  runhandlers(CallableHandler(args...; kwargs...), eff)
end)
```
We provide a convenience macro `@runcallable` which does just this, so you can write `@runcallable eff`.


TODO mention State and how it is different
TODO show that both can be combined manual, however only like Callable(State(eff)).

TODO mention that @runcallable is actually smart enough to do this autmatically.


# Limitations

ExtensibleEffects can do quite a lot, however what is not possible is to deal with infinite iterables. The reason is that ExtensibleEffects always run effects by translating them to operations on values (which then finally reduce the Effect Monad like `Vector` to the Identity Monad `noeffect`.).
With an infinite iterable there is no way at all to extract all the values, hence they are not supported.

Compare this to a ``Callable``. Also here, the value is hidden within the respective function, however we know how to principally get the value, namely by applying correct `args` and `kwargs` to the callable. Hence we can indeed operate on the value within a Callable, which lets us support Callable by ExtensibleEffects. Something like this is not possible with infinite iterables.
