```@meta
CurrentModule = ExtensibleEffects
DocTestSetup  = quote
    using ExtensibleEffects
end
```

# Effects

ExtensibleEffects.jl comes packed with a bunch of effects which can be used right away and in addition provide helpful insights into how to create your own effects. A lot is possible within ExtensibleEffects, but there are also limitations. 

## Easy Effects with trivial handlers

`Vector`, `Iterable`, and also `Writer` only need to define `eff_applies`
```julia
# Vector is supported generically as AbstractArray
ExtensibleEffects.eff_applies(handler::Type{T}, effectful::T) where {T<:AbstractArray} = true
ExtensibleEffects.eff_applies(handler::Type{<:Iterable}, effectful::Iterable) = true
ExtensibleEffects.eff_applies(handler::Type{<:Writer}, effectful::Writer) = true
```
`eff_applies` always needs to be given explicitly. This is especially needed for the autorun feature, and explicitness is also in general useful. 

The definitions for `eff_pure` and `eff_flatmap` follows their default implementations, which use functionality from `TypeClasses`.

```julia
ExtensibleEffects.eff_pure(T, value) = TypeClasses.pure(T, value)

function ExtensibleEffects.eff_flatmap(continuation, a)
  a_of_eff_of_a = map(continuation, a)
  eff_of_a_of_a = flip_types(a_of_eff_of_a)
  eff_of_a = map(flatten, eff_of_a_of_a)
  eff_of_a
end
```


## Option, Try, Either

`Identity` and `Const`, i.e. `Option`, `Try` and `Either`, need a bit more interaction with the effect system.

The design decision of unifying `Option`/`Try`/`Either` by separating normal behaviour into `Identity` and stopping behaviour into `Const` has many advantages. One difficulty, however, is that `Const` does not have a `TypeClasses.pure` implementation, so how do we define `eff_pure`? The answer is an important insight into how `ExtensibleEffects` work: The `pure` function is only called on the final values within all the nested `eff_flatmap` calls. After destructuring all nested effects into plain values, the effects get rewrapped around the plain values. A `Const`, however, is always constant - there is no inner value to work on. That is why we can freely use any `eff_pure` definition, as it will never be run in case of a `Const`. However it will be run within *other* handlers for reconstructing their stack of wrappers. Hence the simplest and sound `eff_pure` implementation is to do nothing but leave the value unchanged. All in all this is the implementation for `Const`

```julia
ExtensibleEffects.eff_flatmap(continuation, effectful::Const) = effectful
ExtensibleEffects.eff_pure(handler::Type{<:Const}, value) = value
```

You see, the continuation is ignored and `eff_pure` just returns the very same value.

The interaction between `Const` and `Identity` needs to be handled in addition. If something would return a `Const` the default implementation of `eff_pure` for `Identity` would wrap it into an `Identity` layer, resulting into `Identity(Const(...))`. This differs from the `TypeClasses.flatmap` implementation which would return just a `Const(...)`. This interaction is crucial for `Option`/`Try`/`Either`. We can implement it by special casing the `eff_pure`

```julia
ExtensibleEffects.eff_pure(handler::Type{<:Identity}, value) = Identity(value)
ExtensibleEffects.eff_pure(handler::Type{<:Identity}, value::Const) = value

ExtensibleEffects.eff_flatmap(continuation, effectful::Identity) = continuation(effectful.value)
```

Take a look at the definition of `eff_flatmap` for `Identity`. `eff_flatmap` gets a `continuation` which when called returns an `Eff{YourEffectType{Value}}` and should always return an `Eff{YourEffectType{Value}}` as well, i.e. `Eff{Identity{Value}}` in our case. Usually it is quite difficult to apply the `continuation` and return the same type, but for `Identity` the case is super simple, as we can just strip away the outer `Identity` layer.

Finally, in case you disable the default `autorun` feature, you may also want to use `Option`/`Try`/`Either` as the handlers instead of specifying the two handlers `Identity` and `Const` separately. This is enabled by explicitly defining `eff_applies` and forwarding the `eff_pure` to the case for `Identity`. The `eff_flatmap` will automatically fallback to those for `Identity` or `Const` respectively.

```julia
ExtensibleEffects.eff_applies(handler::Type{<:Either}, effectful::Either) = true
ExtensibleEffects.eff_pure(handler::Type{<:Either}, value) = ExtensibleEffects.eff_pure(Identity, value)  # Const would never reach this

```

---

All these effects can still be run automatically, without any further context parameters. In ExtensibleEffect terms, this means that `Option`, `Vector`, `Iterable` and the like are handlers by its own and can be autorun.

We acknowledge this everytime we define `eff_applies` like `ExtensibleEffects.eff_applies(handler::Type{<:HandlerType}, value::HandlerType) = true`.


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

The example may be slightly artifical, however you can see nicely how the `eff_pure` function works differently when using an explicit `WriteHandler` handler. Also, you do not see multiple `"pure-accumulator."` accumulating for each single value. Instead you have tight control about whether first the indeterminism by `Vector` should be run and then the accumulator by `Writer` or the other way arround. Either way, in both cases everything is sound and nice.

The handler is defined by

```julia
struct WriterHandler{Acc}
  pure_acc::Acc
end
ExtensibleEffects.eff_applies(handler::WriterHandler, effectful::Writer) = true
ExtensibleEffects.eff_pure(handler::WriterHandler, value) = Writer(handler.pure_acc, value)
```
`eff_flatmap` is the same as for pure `Writer` and defined as
```julia
function ExtensibleEffects.eff_flatmap(continuation, a::Writer)
  eff_of_writer = continuation(a.value)
  map(eff_of_writer) do b
    Writer(a.acc ⊕ b.acc, b.value)
  end
end
```


## Outer Wrappers

There are other effects which really require external parameters in order to work at all. One such monad is `Callable`, i.e. plain functions. A function needs to be called to get at its value, however with which `args` and `kwargs` should the function be called? These need to be given somehow, and hence we require for a specific handler like seen for `WriterHandler`. It is called `CallableHandler` and is defined as follows

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


## Outer Wrappers - ContextManager and the execution order

Another example for a Monad which requires an outer wrapper is the `ContextManager` type from `DataTypesBasic.jl`. It needs a continuation to be run, and ideally should return everything wrapped into a new `ContextManager` so that the executions can be lazy. Very analogous to the requirements of `Callable`, and indeed there is `ContextManagerHandler(continuation)` and `@runcontextmanager`, just like for `Callable`. There is one extra caveat which is very special to ContextManagers and that is the **execution order**.

It turns out, `ContextManager` is actually one of the most difficult computational contexts to be represented within Extensible Effects. This is because, within `Eff` the continuations always return another `Eff`, within which other effects still need to be handled. The computation inside was not fully executed and is hold frozen for later execution. However, the ContextManager semantics really depend on the assumption, that whatever uses the internal value has finished before the ContextManager exits. Otherwise loaded resources may have been destroyed before they are actually used.

The only way to solve this conflict is that the **ContextManager handler needs to run last**. This is actually checked by the `ContextManagerHandler`, however as `@runcontextmanager` wraps everything again into a lazy ContextManager, you need to run it to see the error. The macro version `@runcontextmanager_` (with an underscore) will immediately execute the ContextManager and hence would also directly throw the error.

---

There is further a special handler `ContextManagerCombinedHandler` which improves the execution order for memory performance. 

Let's have a simple factory for ContextManagers for example purposes
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

Alternatively, we can use a combined handler `ContextManagerCombinedHandler` which runs both handlers at once. Intuitively you may think this cannot change anything, but indeed, quite a lot is changed.

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

The difference lies in the different continuations (stored within `Eff.cont`) which are created internally during the run of the handler. When the `Vector` handler was executed independently beforehand, the `ContextManagerHandler` worked with far larger continuations, which actually reached up to the end of the entire computation. Now when running both handlers at once, the continuation is more intuitive, namely the one which only goes up to the end of the for loop iteration (thinking of Vector handling like for loop execution).


## Handlers which need to be updated from one effect to another

The most advanced possibility of defining effects is showcased by `State`. It needs a custom handler which provides the initial state information `StateHandler(state)`, similar to `Callable`. In addition, every effect actually adapts the state, and hence the handler itself must be updated accordingly so that subsequent effects are actually handled with the correct current state. This can be done by implementing your individual `ExtensibleEffects.runhandler` method. Let's take a look on how `StateHandler` is implemented.

```julia
struct StateHandler{T}
  state::T
end
ExtensibleEffects.eff_applies(handler::StateHandler, effectful::State) = true
ExtensibleEffects.eff_pure(handler::StateHandler, value) = (value, handler.state)
```

The type is very simple, it just stores the initial or current state. `eff_applies` is defined the standard way, and `eff_pure` is not returning a `State` object itself, but instead what a standard State function `state -> (value, state)` would return. This is similar to `Callable` where `eff_pure` also does not construct a `Callable`. A difference though is that here we need to change the return value, appending the state, so that outer wrappers can construct a fully valid `State` object.

Now comes the trick to pass on the internal states

```julia
function ExtensibleEffects.runhandler(handler::StateHandler, eff::Eff)
  eff_applies(handler, eff.effectful) || return runhandler_not_applies(handler, eff)
  
  value, nextstate = eff.effectful(handler.state)
  nexthandler = StateHandler(nextstate)
  if isempty(eff.cont)
    _eff_pure(nexthandler, value)
  else
    runhandler(nexthandler, eff.cont(value))
  end
end
```

`ExtensibleEffects.runhandler` is the key function to overwrite if you would like to define what happens *between* evaluations of your effectful type.

1. The first line checks whether our handler `StateHandler` actually applies to the given effectful, and if not, we return the result of a helper function `runhandler_not_applies`.
2. Everything which follows implements the case that our handler applies and hence assumes that `eff.effectful` is of type `State`.
3. We run the `State`, given our previous state from the handler, and get the nextstate which we use to construct the nexthandler.
4. Depending on whether we already reached the end of our effect program `eff`, we either stop with `_eff_pure`, or recurse into `runhandler` again.

Finally, similar to `Callable` and `ContextManager` there also exists a run macro for `State`, called `runstate`, which will wrap everything into a `State` within which the `StateHandler` is run. Let's see everything in action

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
as now the appended state is within the `Callable` and not directly within the `State`, violating the definition of `State`.


## Combining wrappers like `@runcallable`, `@runcontextmanager` and `@runstate`

Within the ExtensibleEffects framework, different *handlers* naturally compose nicely in order to execute all the given effects. Constructing *wrappers* around the solution, like it does `@runcallable` for example, is not part of the standard extensible effects framework though. Nevertheless, especially if you want to replace Monads ([TypeClasses.jl](https://www.github.com/JuliaFunctional/TypeClasses.jl)) with [ExtensibleEffects.jl](https://www.github.com/JuliaFunctional/ExtensibleEffects.jl), being able to construct these wrappers easily and composable makes for a very intuitive plug-and-play interface.

In order to compose wrappers, we currently use a macro approach. Each wrapper (including custom ones) constructs its wrapper-code using macros. Take a look at `@runcallable`
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

Using this style, all wrappers can be written very concisely and combined in arbitrary order (in principle). There is an alternative way of implementating it using nested functions instead of macros, however the syntax would look more polluted and we haven't seen crucial disadvantages of the macro approach yet.

Despite this nice generic composability, as `@runstate` needs always be run first and `@runcontextmanager` needs to run last, in our concrete example the order is given by the semantics of the wrappers: It would be `@runcontextmanager @runcallable @runstate`

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
With an infinite iterable there is no way to extract all the values though. If you know more about your infite iterable, it may become possible again. For instance it could be a simple infinite repetition of the same element. In such cases we indeed can extract "all" values at once, operate on it, and reconstruct the repeating iterable around it.

A second limitation is that we need to know a way to wrap a plain value into our handled effect. While we can always make an `a` into an `[a]`, it is not possible to wrap it into a `Dict` for instance. Which key would you choose? In general, a function like this is called `pure`, and it is needed because ExtensibleEffects work by first breaking down everything into values before reconstructing the respective effects from scratch.

Compare both limitations to the fully supported `Callable` type. Also here, the value is hidden within the respective function, however we know how to principally get the value, namely by applying correct `args` and `kwargs` to the callable. Hence we can indeed operate on the value within a Callable, which lets us support Callable by ExtensibleEffects. Something like this is not possible with infinite iterables. Also we can wrap a value into a Callable by creating a constant function `(args...; kwargs...) -> a`, which is not possible for a dictionary.