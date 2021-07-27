```@meta
CurrentModule = ExtensibleEffects
DocTestSetup  = quote
    using ExtensibleEffects
end
```

# Manual

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

## `eff_applies`, `eff_pure`, `eff_flatmap`

`Vector`, `Iterable` and many more are handled by overwriting the three core functions. We specify them by using Vector as an example:


| core function                                                    | default                                                                                              | description                                                                                                                                                                                                                                                                                                                                                     |
| ------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `eff_applies(handler::Type{<:Vector}, effectful::Vector) = true` | there is no default                                                                                  | specify on which values the handler applies (the handler Vector applies to Vector of course)                                                                                                                                                                                                                                                                    |
| `eff_pure(handler::Type{<:Vector}, value) = [value]`             | defaulting to`TypeClasses.pure` (enough for Vector)                                                  | wrap a plain value into the Monad of the handler, here Vector.                                                                                                                                                                                                                                                                                                  |
| `eff_flatmap(continuation, effectful::Vector)`                   | defaults to using`map`, `flatmap`, and `flip_types` from `TypeClasses` (this is enough for `Vector`) | apply a continuation to the current effect (here again Vector as an example). The key difference to plain`TypeClasses.flatmap` is that `continuation` does not return a plain `Vector`, but a `Eff{Vector}`. Applying this `continuation` with a plain `map` would lead `Vector{Eff{Vector}}`. However, `eff_flatmap` needs to return an `Eff{Vector}` instead. |

## More Complex ExtensibleEffect Handlers

While `Vector`, and `Iterable` have almost trivial implementations, `Identity` and `Const`, i.e. `Option`, `Try` and `Either`, need a bit more interaction with the effect system.

The design decision of unifying `Option`/`Try`/`Either` by separating normal behaviour into `Identity` and stopping behaviour into `Const` has many advantages. One difficulty, however, is that `Const` does not have a `TypeClasses.pure` implementation, so how do we define `eff_pure`? The answer is an important insight into how `ExtensibleEffects` work: The `pure` function is only called on the final values within all the nested `eff_flatmap` calls. After destructuring all nested effects into plain values, the effects get rewrapped around the plain values. A `Const`, however, is always constant - there is no inner value to work on. That is why we freely use any `eff_pure` definition, as it will never be used in case of a `Const`. The simplest version is to do nothing. All in all this is the implementation for `Const`

``````julia

ExtensibleEffects.eff_flatmap(continuation, a::Const) = a
ExtensibleEffects.eff_pure(handler::Type{<:Const}, a) = a

``````

You see, the continuation is ignored and the `pure` just returns the very same value.

The interaction between `Const` and `Identity` needs to be handled in addition. If something would return a `Const` the default implementation of `eff_pure` for `Identity` would wrap it into an `Identity` layer, resulting into `Identity(Const(...))`. This differs from the `TypeClasses.flatmap` implementation which would return just a `Const(...)`. This interaction is crucial for `Option`/`Try`/`Either`. We can implement it by special casing the `eff_pure`

```julia
ExtensibleEffects.eff_pure(handler::Type{<:Identity}, a) = Identity(a)
ExtensibleEffects.eff_pure(handler::Type{<:Identity}, a::Const) = a

ExtensibleEffects.eff_flatmap(continuation, a::Identity) = continuation(a.value)
```

Take a look at the definition of `eff_flatmap` for `Identity`. `eff_flatmap` gets a `continuation` which when called returns an `Eff{YourEffectType{Value}}` and should always return an `Eff{YourEffectType{Value}}` as well, i.e. `Eff{Identity{Value}}`in our case. Usually it is quite difficult to apply the `continuation` and return the same type, but for `Identity` the case is super simple, as we can just strip away the one `Identity` layer.

Finally, in case you disable the default `autorun` feature, you may also want to use `Option`/`Try`/`Either` as the handlers instead of specifying the two handlers `Identity` and `Const` separately. This is enabled by explicitly defining `eff_applies` and forwarding the `eff_pure` to the case for `Identity`.

```julia
ExtensibleEffects.eff_applies(handler::Type{<:Either}, value::Either) = true
ExtensibleEffects.eff_pure(handler::Type{<:Either}, a) = ExtensibleEffects.eff_pure(Identity, a)  # Const would never reach this

```

---

All these can still be run automatically, without any further context parameters. In ExtensibleEffect terms, this means that `Option`, `Vector`, `Iterable` and the like are handlers by its own and can be autorun.

We acknowledge this everytime we define `eff_applies` like such `ExtensibleEffects.eff_applies(handler::Type{<:HandlerType}, value::HandlerType) = true`.

## Handlers With Additional Parameters

The `Writer` monad is actually similar to `Vector` when using its default accumulator `TypeClasses.neutral`.

```jldoctest
julia> @syntax_eff begin
         a = Writer("hello.", 1)
         b = Writer("world.", 2)
         @pure a + b
       end
Writer{String, Int64}("hello.world.", 3)
```

However, if you want to use another accumulator as the default one, extra adaptations are required. Unlike `Option` such a parameter cannot be added by simply overloading `eff_pure` or the like, but we need an extra handler type which can carry all additional information needed.

```jldoctest
julia> @runhandlers (WriterHandler("pure-accumulator."), Vector) @syntax_eff_noautorun begin
         a = Writer("hello.", 1)
         b = Writer("world.", 2)
         c = [3, 4]
         @pure a + b + c
       end
Writer{String, Vector{Int64}}("hello.world.pure-accumulator.", [6, 7])

julia> @runhandlers (Vector, WriterHandler("pure-accumulator.")) @syntax_eff_noautorun begin
         a = Writer("hello.", 1)
         b = Writer("world.", 2)
         c = [3, 4]
         @pure a + b + c
       end
2-element Vector{Writer{String, Int64}}:
 Writer{String, Int64}("hello.world.pure-accumulator.", 6)
 Writer{String, Int64}("hello.world.pure-accumulator.", 7)
```

The example may be slightly artifical, however you can see nicely, how the `eff_pure` function works differently when using an explicit `WriteHandler` handler.

The handler is defined by

```julia
struct WriterHandler{Acc}
  pure_acc::Acc
end
ExtensibleEffects.eff_applies(handler::WriterHandler{Acc}, value::Writer{Acc}) where Acc = true
ExtensibleEffects.eff_pure(handler::WriterHandler, value) = Writer(handler.pure_acc, value)
```

Take a look again at the above example which runs both `WriterHandler` and `Vector`. It gives you feeling of when `eff_pure` is called internally, namely only when reconstructing the respective effect layer. You do not see multiple `"pure-accumulator."` accumulating for each single value. Instead you have tight control about whether first the indeterminism by `Vector` should be run and then the accumulator by `Writer` or the other way arround. Either way, in both cases everything is sound and nice.

## Outer Handlers

There are other Monads which really require external parameters to be run at all. One such monad is `Callable`, i.e. plain functions. A function needs to be called to get at its value, however with which `args` and `kwargs` should the function be called? These need to be given somehow, and hence we require for a specific handler like seen for `WriterHandler`. It is called `CallableHandler` and is defined as follows

```julia
struct CallableHandler{Args, Kwargs}
  args::Args
  kwargs::Kwargs
end
ExtensibleEffects.eff_applies(handler::CallableHandler, value::Callable) = true
ExtensibleEffects.eff_pure(handler::CallableHandler, a) = a
function ExtensibleEffects.eff_flatmap(handler::CallableHandler, continuation, a::Callable)
  continuation(a(handler.args...; handler.kwargs...))
end
```

In addition, we would like to construct a `Callable` as the return value, i.e. wrapping everything into a Function itself which asks for the `args` and `kwargs`. We do this by a special macro `@runcallable` which can be composed with other such outer wrappers thanks to the `ExtensibleEffects.@insert_into_runhandlers` helper macro.

```julia
@runcallable eff
```

translates to

```julia
Callable(function(args...; kwargs...)
  @insert_into_runhandlers CallableHandler(args...; kwargs...) eff
end)
```

Types like `Callable` cannot be autorun, and thankfully, `ExtensibleEffects` can recognize this automatically. All in all we get

```jldoctest
julia> f = @runcallable @syntax_eff begin
         a = Callable(x -> x*x)
         b = Callable(x -> 2x)
         @pure a + b
       end;

julia> f(7)
63
```

## Outer Handler - ContextManager and the execution order

Another example for a Monad which requires an outer handler is the `ContextManager` type from `DataTypesBasic.jl`. It needs to continuation to be run, and ideally should return everything wrapped into a new `ContextManager` so that the executions can be lazy. Very analogous to the requirements of `Callable`. And indeed there is `ContextManagerHandler(continuation)` and `@runcontextmanager`, just like for `Callable`. There is one extra caveat which is very special to ContextManagers and that is the **execution order**.

It turns out, `ContextManager` is actually one of the most difficult computational contexts to be represented within Extensible Effects. This is because, within `Eff` the continuations always return another `Eff`, within which other effects still need to be handled. The computation inside was not fully executed and is hold frozen for later execution. However, the ContextManager semantics really depend on the assumption, that whatever uses the internal value has finished before the ContextManager exits. Otherwise resource may have been destroyed before they are actually used.

The only way to solve this conflict is that the **contextmanager handler needs to run last**. This is actually checked by the `ContextManagerHandler`, however as `@runcontextmanager` wraps everything again into a lazy ContextManager, you need to run it to see the error.

---

There is further a special handler `ContextManagerCombinedHandler` which improves the execution order for memory performance. Let's have a simple factory for ContextManagers for example purposes

```jldoctest contextmanager
julia> create_context(x) = @ContextManager continuation -> begin
           println("before $x")
           result = continuation(x)
           println("after $x")
           result
       end
create_context (generic function with 1 method)

julia> println_return(x) = (println(x); x)
println_return (generic function with 1 method)
```

Using `ContextManagerHandler` we get

```jldoctest contextmanager
julia> eff = @syntax_eff begin
         a = [100,200]
         b = create_context(a)
         c = [5,6]
         d = create_context(a + c)
         @pure a, b, c, d
       end;

julia> @runhandlers (ContextManagerHandler(println_return),) eff
before 100
before 105
before 106
before 200
before 205
before 206
[(100, 100, 5, 105), (100, 100, 6, 106), (200, 200, 5, 205), (200, 200, 6, 206)]
after 206
after 205
after 200
after 106
after 105
after 100
4-element Vector{NTuple{4, Int64}}:
 (100, 100, 5, 105)
 (100, 100, 6, 106)
 (200, 200, 5, 205)
 (200, 200, 6, 206)
```

Alternatively, we can use a combined handler `ContextManagerCombinedHandler` which runs both handlers at once. Intuitively you may think this cannot change anything, but indeed quite a lot is changed.

```jldoctest contextmanager
julia> eff = @syntax_eff noautorun(Vector) begin
         a = [100,200]
         b = create_context(a)
         c = [5,6]
         d = create_context(a + c)
         @pure a, b, c, d
       end
Eff(effectful=[100, 200], length(cont)=1)

julia> handlers = (ContextManagerCombinedHandler(Vector, println_return),)
(ContextManagerCombinedHandler{Type{Vector{T} where T}, typeof(println_return)}(Vector{T} where T, ContextManagerHandler{typeof(println_return)}(println_return)),)

julia> @runhandlers handlers eff
before 100
before 105
(100, 100, 5, 105)
after 105
before 106
(100, 100, 6, 106)
after 106
after 100
before 200
before 205
(200, 200, 5, 205)
after 205
before 206
(200, 200, 6, 206)
after 206
after 200
4-element Vector{NTuple{4, Int64}}:
 (100, 100, 5, 105)
 (100, 100, 6, 106)
 (200, 200, 5, 205)
 (200, 200, 6, 206)
```

The difference lies in the different `continuation`s which are created internally during the run of the handler. When the `Vector` handler was run independently beforehand, the `ContextManagerHandler` worked with far larger continuations, which actually reached up to the end of the entire computation. Now when running both handlers at once, the continuation is more intuitive, namely the one which only goes up to the end of the for loop iteration (thinking of Vector handling like for loop execution).

## Handlers which need to be updated from one effect to another

The most advanced possibility to define effects is showcased by `State`. It needs a custom handler which provides the initial state information `StateHandler(state)`, similar to `Callable`. In addition, every effect actually adapts the state, and hence the handler itself must be updated accordingly so that subsequent effects are actually handled with the correct current state. This can be done by implementing your individual `ExtensibleEffects.runhandler` method. Let's take a look on how `StateHandler` is implemented.

```julia
struct StateHandler{T}
  state::T
end
ExtensibleEffects.eff_applies(handler::StateHandler, value::State) = true
ExtensibleEffects.eff_pure(handler::StateHandler, value) = (value, handler.state)
```

The type is very simple, it just stores the initial or current state. `eff_applies` and `eff_pure` are defined the standard way.

Now comes the trick to pass on the internal states

```julia
function ExtensibleEffects.runhandler(handler::StateHandler, eff::Eff)
  eff_applies(handler, eff.effectful) || return runhandler_not_applies(handler, eff)
  
  nextvalue, nextstate = eff.effectful(handler.state)
  nexthandler = StateHandler(nextstate)
  if isempty(eff.cont)
    _eff_pure(nexthandler, nextvalue)
  else
    runhandler(nexthandler, eff.cont(nextvalue))
  end
end
```

`ExtensibleEffects.runhandler` is the key function to overwrite if you would like to define what happens *between* evaluations of your effectful type.

1. The first line checks whether our handler `StateHandler` actually applies to the given effectful, and if not, we return the result of a helper function `runhandler_not_applies`.
2. Everything which follows implements the case that our handler applies and hence assumes that `eff.effectful` is of type `State`.
3. We run the State, given our previous state from the handler, and get the nextstate which we use to construct the nexthandler.
4. Depending on whether the given `eff` possibly contains further `State` types, we either stop with `_eff_pure`, or recurse into `runhandler` again.

Finally, similar to `Callable` and `ContextManager` there also exists a run macro for `State`, called `runstate`, which will wrap everything into a State within which the `StateHandler` is run. Seeing everything it in action looks like

```jldoctest
julia> state_eff = @runstate @syntax_eff begin
         a = State(x -> (x+2, x*x))
         b = State(x -> (a + x, x+1))
         @pure a, b
       end;

julia> state_eff(3)
((5, 14), 10)
```

Note that unlike `Callable` and `ContextManager`, a `State` always has to ensure that it is the **first outer wrapper** being run,
because it returns the inner state as an additional argument.

If you would nest it within  `@runcallable`, e.g. like `@runstate @runcallable eff` it wouldn't work,
as now the appended state is within the `Callable` and not directly within the `State`.

## Combining wrappers like `@runcallable`, `@runcontextmanager` and `@runstate`

Within the ExtensibleEffects framework, different *handlers* naturally compose nicely in order to execute all the given effects. Constructing *wrappers* around the solution, like it does `@runcallable` for example, is not part of the standard extensible effects framework. Nevertheless, especially if you want to replace Monads ([TypeClasses.jl](https://www.github.com/JuliaFunctional/TypeClasses.jl)) with [ExtensibleEffects.jl](https://www.github.com/JuliaFunctional/ExtensibleEffects.jl), being able to construct these wrappers easily creates a very intuitive plug-and-play interface. Further we would like to compose them, too.

In order to compose such wrappers, we currently use a macro approach. Each wrapper (including custom ones) constructs its wrapper-code using macros. Take a look at `@runcallable`
again. It is defined like

```julia
macro runcallable(expr)
  esc(:(Callable(function(args...; kwargs...)
    @insert_into_runhandlers CallableHandler(args...; kwargs...) ($expr)
  end)))
end
```

i.e.

```julia
@runcallable eff
```

translates to

```julia
Callable(function(args...; kwargs...)
  @insert_into_runhandlers CallableHandler(args...; kwargs...) eff
end)
```

`@insert_into_runhandlers` will expand all inner macros and search for a call to `runhandlers` in order to insert the newly constructed `CallableHandler`. If no `runhandlers` is found, it will call it itself.

Using this style, all wrappers can be written very concisely and combined in arbitrary order (in principle). There is an alternative way of implementation which uses nested functions instead of macros, however the syntax would look more polluted and we haven't yet seen crucial disadvantages of the macro approach.

As `@runstate` needs always be run first and `@runcontextmanager` needs to run last, in our concrete example though the order is given by the semantics of the wrappers. It would be `@runcontextmanager @runcallable @runstate`

```jldoctest contextmanager
julia> contextmanager_callable_state = @runcontextmanager @runcallable @runstate @syntax_eff begin
         co = create_context(42)
         st = State(s -> (co+s, s*s))
         ca = Callable(x -> x + st + co)
         @pure co, st, ca
       end;

julia> typeof(contextmanager_callable_state).name
typename(ContextManager)

julia> typeof(contextmanager_callable_state(println_return)).name
typename(Callable)

julia> typeof(contextmanager_callable_state(println_return)(3)).name
typename(State)

julia> contextmanager_callable_state(println_return)(3)(9)
before 42
((42, 51, 96), 81)
after 42
((42, 51, 96), 81)
```

## Limitations

ExtensibleEffects can do quite a lot, however some things are just not possible.

One such limitation are infinite iterables. They are not supportable. The reason is that ExtensibleEffects always run effects by translating them to operations on plain values.
With an infinite iterable there is no way to extract all the values though. If you know more about your infite iterable, it my get possible again. For instance it could be a simple infinite repetition of the same element. In such cases we indeed can extract "all" values at once, operate on it, and reconstruct the repeating iterable around it.

A second limitation is that we need to know a way to wrap a plain value into our handled effect. While we can always make an `a` into an `[a]`, it is not possible to wrap it into a `Dict` for instance. Which key would you choose? In general, a function like this is called `pure`, and it is needed because ExtensibleEffects work by first breaking down everything into values before reconstructing the respective effects from scratch.

Compare both limitations to the fully supported `Callable` type. Also here, the value is hidden within the respective function, however we know how to principally get the value, namely by applying correct `args` and `kwargs` to the callable. Hence we can indeed operate on the value within a Callable, which lets us support Callable by ExtensibleEffects. Something like this is not possible with infinite iterables. Also we can wrap a value into a Callable by creating a constant function `(args...; kwargs...) -> a`, which is not possible for a dictionary.

## How does it actually work?

`ExtensibleEffects` put everything into the meta monad `Eff` and somehow magically by doing so different monads can compose well together.

### Key ingredients

There are two main ingredience for this magic to work:

1. `Eff` is itself a Monad, hence you can work *within* `Eff` without caring about the precise workings of the computational context `Eff`.
2. `Eff` is not only an arbitrary Monad, but a very generic one, sometimes called a kind of *free* Monad. The key result is that we can represent many many of our well known Monads into this `Eff` monad.
3. The ExtensibleEffects system guarantees that the `continuation` in `eff_flatmap(handler, continuation, effectful)` will always return an `Eff` with element type of the same type as `effectful` itself. This makes it possible to define your own effect-handlers *independent* of all the other effect-handlers.

The monad implementation is very simple indeed.

```julia
TypeClasses.pure(::Type{<:Eff}, a) = noeffect(a)
TypeClasses.map(f, eff::Eff) = TypeClasses.flatmap(noeffect ∘ f, eff)
TypeClasses.flatmap(f, eff::Eff) = Eff(eff.effectful, Continuation(eff.cont.functions..., f))
```

In brief, it just stores all functions for later execution in the `Continuation` attribute `cont`. The first function in the `Continuation` is later applied directly to the `eff.effectful`, the second function in `cont` is applied to the result of the first function, the third to the result of that, and so forth (with the addition that all functions return `Eff` which wrap the results). That is it.

---

Let's look at the third ingredient, why the continuation always returns an `Eff` of the very same type.

What is actually the element type of an `Eff`? It is not the typeparameter `Eff{ElementType}`, because `Eff` is defined as `Eff{Effectful, Continuation}`.
We can nevertheless get an intuitive feeling for the element type: When using `map`/`flatmap` like in

```julia
flatmap(eff) do value
  # ...
end
```

The element is the argument to our anonymous function which we map over the container. For example above, the element type would be `typeof(value)`.

For `Eff` the `value` of `flatmap` is specified by whatever function is mapped right befor our call to map. To understand what this is, we need to take a look into whatever is calling our `eff_flatmap`. It turns out this is `ExtensibleEffects.runhandler`. Here is its definition:

```julia
function runhandler(handler, eff::Eff)
  eff_applies(handler, eff.effectful) || return runhandler_not_applies(handler, eff)

  interpreted_continuation = if isempty(eff.cont)
    # `_eff_pure` just calls `eff_pure` and ensures that the return value is of type `Eff`
    Continuation(x -> _eff_pure(handler, x))
  else
    Continuation(x -> runhandler(handler, eff.cont(x)))
  end
  # `_eff_flatmap` just calls `eff_flatmap` and ensures that the return value is of type `Eff`
  _eff_flatmap(handler, interpreted_continuation, eff.effectful)
end
```

It is quite similar to our custom handler we wrote for `State`. In the first line we again check whether our current handler actually applies. For our purposes at the moment, we are only interested in the case where it applies, so we can go on to line 3: Here we construct the actual continuation which is then passed to `eff_flatmap`.
The last line then is already our call to `eff_flatmap` which we wanted to understand in more detail.

Let's summarize the situation and the goal again. It is simpler to follow if we take concrete example. Let's consider that `eff.effectful` is of type `Vector`, and that also `handler = Vector`. We want to understand why the continuation, here `interpreted_continuation`, is returning an `Eff` with element type `Vector` as well.

Looking at the definition of `interpreted_continuation` we can directly read out its return value.

1. In the first case, if `isempty(eff.cont)`, we get an `_eff_pure(Vector, ...)` which indeed will construct an `Eff` with element type `Vector` (the continuation of that `Eff` is still empty).
2. In the second case we get `runhandler(Vector, eff.cont(x))`, which recurses into our very function `runhandler` itself. What does it return?

   1. If the `Vector` handler applies to the next effect `eff.cont(x)::Eff`, we return `eff_flatmap(...)`. Remember `eff_flatmap` belongs to the core interface and indeed for `Vector` always return an `Eff` of element type `Vector`, if everything goes right.
   2. If the `Vector` handler does not apply to the next effect `eff.cont(x)`, we return `runhandler_not_applies(Vector, eff)`. Here is its definition

      ```julia
      function runhandler_not_applies(handler, eff::Eff)
        interpreted_continuation = if isempty(eff.cont)
          Continuation(x -> _eff_pure(handler, x))
        else
          Continuation(x -> runhandler(handler, eff.cont(x)))
        end
        Eff(eff.effectful, interpreted_continuation)
      end
      ```

      The `interpreted_continuation` is constructed exactly identically. The only difference is that instead of calling `eff_flatmap`, we construct an `Eff` which will remember to run our handler for subsequent effects. We are interested in the element type of this returned `Eff`, which is directly defined by what `interpreted_continuation` returns, same as before.

      1. In the first case we have `_eff_pure(Vector, ...)` again, which is an Eff of element type Vector.
      2. In the second case we recurse one more time into our well known `runhandler(Vector, ...)`, what does it return? At this point we already have been once. We have seen all branches our function can take: There was the `_eff_pure(Vector, ...)` branch, which is returning an `Eff` of element type `Vector` quite trivially. There was `_eff_flatmap` which does so as well by definition. Finally there is the recursion branch. Assuming now that the recursion ends, it will itself end in branch one or two and hence also return an `Eff` of element type `Vector`.

To emphasize one implicit but very important aspect of the above argument: Whether things are actually computed or just stored for later execution, to understand which element type the `Eff` has it is not decisive. Everything which matters is what is going to be executed right before. This way the different handlers can actually stack their computations on top of each other without interferring.

### Extensive Advanced Example

Finally let's look at a concrete example of running two simple handlers, `Vector` and `Writer`.

```jldoctest
julia> @syntax_eff begin
         a = [2, 3]
         b = Writer("hello.", a*a)
         c = [7, 8]
         d = Writer("world.", a+b+c)
         @pure a, b, c, d
       end
4-element Vector{Writer{String, NTuple{4, Int64}}}:
 Writer{String, NTuple{4, Int64}}("hello.world.", (2, 4, 7, 13))
 Writer{String, NTuple{4, Int64}}("hello.world.", (2, 4, 8, 14))
 Writer{String, NTuple{4, Int64}}("hello.world.", (3, 9, 7, 19))
 Writer{String, NTuple{4, Int64}}("hello.world.", (3, 9, 8, 20))

julia> eff = @syntax_eff_noautorun begin
         a = [2, 3]
         b = Writer("hello.", a*a)
         c = [7, 8]
         d = Writer("world.", a+b+c)
         @pure a, b, c, d
       end
Eff(effectful=[2, 3], length(cont)=1)
```

`@syntax_eff` uses autorun and hence is just the same as manually running `@runhandlers (Vector, Writer) @syntax_eff_noautorun ...`, which again translates into

```julia
import ExtensibleEffects: runhandler, runlast_ifpossible, Continuation
runlast_ifpossible(runhandler(Vector, runhandler(Writer, eff)))
```

where `eff` refers to the above variable storing the result of `@syntax_eff_noautorun`. Let's go step by step:

* we start with `runhandler(Writer, eff)`
* the first effect found is not of type Writer, and the `Eff` has still a continuation left, i.e. `eff.cont` is not empty. Hence we construct `Eff(eff.effectful, interpreted_continuation_Writer1)` where `interpreted_continuation_Writer1` recurses into `runhandler` using the handler `Writer`. The inner `eff.cont` is the very first continuation, capturing the entire computation.

  ```julia
  original_continuation1(a) = @syntax_eff_noautorun begin
    b = Writer("hello.", a*a)
    c = [7, 8]
    d = Writer("world.", a+b+c)
    @pure a, b, c, d
  end

  interpreted_continuation_Writer1(a) = runhandler(Writer, original_continuation1(a))
  ```
* `eff2 = runhandler(Writer, eff)` already returns
* `runhandler(Vector, eff2)` is run
* the first effect found is of type Vector, and the `eff2.cont` is again non-empty - it is just our `interpreted_continuation_Writer1`. Hence we will construct a new continuation, let's call it `interpreted_continuation_Vector1`, which recurses into `runhandler` using the handler `Vector`. We can specify it more concretely as

  ```julia
  interpreted_continuation_Vector1 = Continuation(x -> runhandler(Vector, interpreted_continuation_Writer1(x)))
  ```
* this `interpreted_continuation_Vector1` is now passed to `eff_flatmap` for Vector which will call this continuation for all values, here `2` and `3`.
* `interpreted_continuation_Vector1(2)` returns the results of this first branch, which is now a pure value (which you can see at `length(cont)=0`)

  ```julia
  julia> interpreted_continuation_Vector1(2)
  Eff(effectful=NoEffect{Vector{Writer{String, NTuple{4, Int64}}}}(Writer{String, NTuple{4, Int64}}[Writer{String, NTuple{4, Int64}}("hello.world.", (2, 4, 4, 10)), Writer{String, NTuple{4, Int64}}("hello.world.", (2, 4, 5, 11))]), length(cont)=0)
  ```

  * Let's look into `interpreted_continuation_Writer1(2)`

    ```julia
    julia> eff3 = interpreted_continuation_Writer1(2)
    Eff(effectful=[4, 5], length(cont)=2)
    ```

    * Given `a = 2`, the original program could continue and returned an `Eff` with the first `Writer` as its effectful value and all the rest as the continuation.

      ```julia
      function original_continuation2(b)
        a = 2
        @syntax_eff_noautorun begin
          c = [7, 8]
          d = Writer("world.", a+b+c)
          @pure a, b, c, d
        end
      end
      ```
    * Then `runhandler(Writer, ...)` was called on top if it, finding an effectful `Writer` and non-empty continuation `original_continuation2` and hence constructing a new continuation

      ```julia
      interpreted_continuation_Writer2 = Continuation(x -> runhandler(Writer, original_continuation2(x)))
      ```

      which is then passed to `eff_flatmap`.
    * Within `eff_flatmap`, the `Writer`'s inner value is extracted, a `4 = 2*2`, and passed on to the continuation.

      ```julia
      julia> interpreted_continuation_Writer2(4)
      Eff(effectful=[7, 8], length(cont)=1)
      ```

      Here what happened step by step:

      * `eff4 = original_continuation2(4)` was called, returning the next program step `Eff(effectful=[4, 5], length(cont)=1)`
      * `runhandler(Writer, eff4)` found a Vector which it cannot handle, and in addition the Effect has a non-empty continuation. Hence it returns an `Eff` with the same effectful (the Vector here) and applying `runhandler(Writer, ...)` to the continuation.

        ```julia
        function original_continuation3(c)
          a = 2
          b = 4
          @syntax_eff_noautorun begin
            d = Writer("world.", a+b+c)
            @pure a, b, c, d
          end
        end

        interpreted_continuation_Writer3 = Continuation(x -> runhandler(Writer, original_continuation3(x)))
        ```

        That is also why the length of `eff.cont` hasn't changed. `original_continuation3` was simply replaced with `interpreted_continuation_Writer3`.
    * finally `eff_flatmap` for `Writer` will work within the returned `Eff` using `Eff`' monad-power, and combine its accumulator to the accumulator of the going-to-be Writer within the `Eff`.

      ```julia
      function ExtensibleEffects.eff_flatmap(continuation, a::Writer)
        eff_of_writer = continuation(a.value)
        map(eff_of_writer) do b
          Writer(a.acc ⊕ b.acc, b.value)
        end
      end
      ```

      As `Eff` does not actually compute anything, but just stores the computation for later execution by appending it to `eff.cont`, we arrive at our final result

      ```julia
      julia> eff3 = interpreted_continuation_Writer1(2)
      Eff(effectful=[7, 8], length(cont)=2)
      ```
  * `runhandlers(Vector, eff3)`

    * it will find an effectful of the correct type and a non-empty continuation, hence creating a continuation

      ```julia
      interpreted_continuation_Vector2(x) = runhandler(Vector, eff3.cont(x))
      ```

      and passing it to `eff_flatmap`
    * `eff_flatmap` will now run it for both of its values `7` and `8`, starting with `7`
    * `eff3.cont(7)` gives a pure result (`length(cont)=0`) of type `NoEffect{Writer}`. Note that this is not a `Writer` effect, but really the end-result which gets wrapped into the trivial effect `NoEffect`.

      ```julia
      julia> eff3.cont(7)
      Eff(effectful=NoEffect{Writer{String, NTuple{4, Int64}}}(Writer{String, NTuple{4, Int64}}("hello.world.", (2, 4, 7, 13))), length(cont)=0)
      ```

      How does this came about?

      * `eff3.cont` contains two continuations, the first was `interpreted_continuation_Writer3` (`original_continuation3` followed by `runhandler(Writer, ...)`) and the second came from the extra `map` operation from within `Writer`'s `eff_flatmap` operation.
      * `eff5 = original_continuation3(7)` just continues our original program

        ```julia
        julia> original_continuation3(7)
        Eff(effectful=Writer{String, Int64}("world.", 13), length(cont)=1)
        ```

        The continuation in here is just the last part of our program

        ```julia
        function original_continuation4(d)
          a = 2
          b = 4
          c = 7
          # the following is invalid syntax, because julia cannot typeinfer the effect type which would be needed to call `pure`
          # @syntax_eff_noautorun begin
          #   @pure a, b, c, d
          # end

          # instead we can construct pure manually
          noeffect((a, b, c, d))
        end
        ```
      * `interpreted_continuation_Writer3(7)` is just `runhandler(Writer, eff5)`. The `Writer` handler finds a matching effectful and non-empty continuation, hence creating a new continuation

        ```julia
        interpreted_continuation_Writer4(x) = runhandler(Writer, original_continuation4(x))
        ```

        which is then passed into Writer's `eff_flatmap`

        * `eff_flatmap` extracts the value from the current `Writer`, which is `13` here, and passes it to the continuation
        * The original continuation returns a `NoEffect` effect type which contains the final `Tuple`

          ```julia
          julia> eff6 = original_continuation4(13)
          Eff(effectful=NoEffect{NTuple{4, Int64}}((2, 4, 7, 13)), length(cont)=0)
          ```
        * Calling `runhandler(Writer, eff6)` on it will find non matching effect and empty continuation. Hence it constructs a new `Eff` with original value and new continuation `x -> eff_pure(Writer, x)`.

          ```julia
          julia> runhandler(Writer, eff6)
          Eff(effectful=NoEffect{Writer{typeof(TypeClasses.neutral), NTuple{4, Int64}}}(Writer{typeof(TypeClasses.neutral), NTuple{4, Int64}}(TypeClasses.neutral, (2, 4, 7, 13))), length(cont)=0)
          ```
        * For performance reasons the `Eff` constructor will directly execute any computation which is run on an `NoEffect` effect. This explains the new effectful and `length(cont)=0`. You also see that mapping over `NoEffect` will actually get the wrapped value (here a `Tuple`) as the input, which is then wrapped into `Writer`.
        * `eff_flatmap` will then merge the accumulators, namely the `"world."` from the plain `Writer` as well as the pure accumulator `TypeClasses.neutral` introduced by `eff_pure`. The merging is again realized by mapping over the `Eff`, and as we reached `NoEffect` effect, all computations are now directly executed.
      * at last the old `eff_flatmap` operation gets active, which now merges the accumulators of the inner Writer `"world."` and the outer accumulator `"hello."`. The merging is again realized by mapping over the `Eff`, and as the effect is already `NoEffect`, the computation is executed immediately, giving us

        ```julia
        julia> eff3.cont(7)
        Eff(effectful=NoEffect{Writer{String, NTuple{4, Int64}}}(Writer{String, NTuple{4, Int64}}("hello.world.", (2, 4, 7, 13))), length(cont)=0)
        ```
    * `runhandler(Vector, eff3.cont(7))` finds now an `Eff` with empty continuation and different type `Writer`, hence a new `Eff` is build with `eff_pure`

      ```julia
      Eff(eff3.effectful, Continuation(x -> _eff_pure(Vector, x)))
      ```

      For performance improvements, the computation on `NoEffect` is again directly executed, leading into a new `NoEffect` of `Vector` of `Writer`.

      ```julia
      julia> runhandler(Vector, eff3.cont(7))
      Eff(effectful=NoEffect{Vector{Writer{String, NTuple{4, Int64}}}}(Writer{String, NTuple{4, Int64}}[Writer{String, NTuple{4, Int64}}("hello.world.", (2, 4, 7, 13))]), length(cont)=0)
      ```
    * The same happens for value `8`, returning another `Eff` of `NoEffect` of `Vector` of `Writer`
    * Using the monad power of `Eff`, both results are now combined by flattening them

      ```julia
      julia> @syntax_flatmap begin
              a = interpreted_continuation_Vector2(7)
              b = interpreted_continuation_Vector2(8)
              @pure [a...; b...]
            end
      Eff(effectful=NoEffect{Vector{Writer{String, NTuple{4, Int64}}}}(Writer{String, NTuple{4, Int64}}[Writer{String, NTuple{4, Int64}}("hello.world.", (2, 4, 7, 13)), Writer{String, NTuple{4, Int64}}("hello.world.", (2, 4, 8, 14))]), length(cont)=0)
      ```

      The concrete implementation of `Vector`'s `eff_flatmap` is slightly more general, but the principle is the same.
* the continuation for the outer Vector (`interpreted_continuation_Vector1`) is now executed for the second value `3`, too,  giving another `NoEffect` plain value.
* analogously to how the inner two computations have been merged, also the outer two `Eff` of `NoEffect` of `Vector` get merged. We almost have our end result.

  ```julia
  julia> runhandler(Vector, runhandler(Writer, eff))
  Eff(effectful=NoEffect{Vector{Writer{String, NTuple{4, Int64}}}}(Writer{String, NTuple{4, Int64}}[Writer{String, NTuple{4, Int64}}("hello.world.", (2, 4, 7, 13)), Writer{String, NTuple{4, Int64}}("hello.world.", (2, 4, 8, 14)), Writer{String, NTuple{4, Int64}}("hello.world.", (3, 9, 7, 19)), Writer{String, NTuple{4, Int64}}("hello.world.", (3, 9, 8, 20))]), length(cont)=0)
  ```
* Finally `runlast_ifpossible` tries to extract the value out of the `Eff`-`NoEffect` combination.

  ```julia
  julia> runlast_ifpossible(runhandler(Vector, runhandler(Writer, eff)))
  4-element Vector{Writer{String, NTuple{4, Int64}}}:
  Writer{String, NTuple{4, Int64}}("hello.world.", (2, 4, 7, 13))
  Writer{String, NTuple{4, Int64}}("hello.world.", (2, 4, 8, 14))
  Writer{String, NTuple{4, Int64}}("hello.world.", (3, 9, 7, 19))
  Writer{String, NTuple{4, Int64}}("hello.world.", (3, 9, 8, 20))
  ```

We have seen the concrete execution of one example, including how the effect system separates lazy computation from actual computation. As long as we haven't reached `NoEffect` and still have unkown handlers to handle, all computation is just lazily stored as functions for later execution. As soon as all handlers are handled, the result is wrapped into the special `NoEffect` effect, on which computation is now executed immediately. From the perspective of the user, the precise timing when something is executed is just an implementation. Hence also `NoEffect` is an implementation detail and you never need to worry about it. Still I hope this helped the interested reader to understand in more detail what is going on behind the scenes.

---

That is it, I hope it is a little bit less magical now, however I myself have to commit that even after implementing the whole package, the power of the extensible effects concept keeps blowing my mind and stays magic.
