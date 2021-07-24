using ExtensibleEffects
using DataTypesBasic
using TypeClasses
using Distributed

# Generic implementations
# -----------------------

# standard pure - fallback to TypeClass.pure
ExtensibleEffects.eff_pure(T, a) = TypeClasses.pure(T, a)

# standard eff_flatmap - fallback to map, flip_types, and flatten
function ExtensibleEffects.eff_flatmap(continuation, a)
  a_of_eff_of_a = map(continuation, a)
  eff_of_a_of_a = flip_types(a_of_eff_of_a)
  eff_of_a = map(flatten, eff_of_a_of_a)
  eff_of_a
end

# NoEffect
# --------
ExtensibleEffects.eff_applies(handler::Type{<:NoEffect}, value::NoEffect) = true
ExtensibleEffects.eff_pure(handler::Type{<:NoEffect}, a) = a
ExtensibleEffects.eff_flatmap(continuation, a::NoEffect) = continuation(a.value)

# Identity
# --------
# we choose to Identity{T} instead of plain T to be in accordance with behaviour of syntax_flatmap
ExtensibleEffects.eff_applies(handler::Type{<:Identity}, value::Identity) = true
ExtensibleEffects.eff_pure(handler::Type{<:Identity}, a) = Identity(a)
# Extra handling of Const so that order of executing Const or Identity handler does not matter
# This is especially important for ExtensibleEffects.autorun, as here it might be "random" whether we first see
# an Identity or a Const
ExtensibleEffects.eff_pure(handler::Type{<:Identity}, a::Const) = a
ExtensibleEffects.eff_flatmap(continuation, a::Identity) = continuation(a.value)

# Const
# -----
ExtensibleEffects.eff_applies(handler::Type{<:Const}, value::Const) = true
# usually Const does not have a pure, however within Eff, it is totally fine,
# as continuations on Const never get evaluated anyways, 
# (and eff_pure is only called at the very end, when literal values are reached)
ExtensibleEffects.eff_pure(handler::Type{<:Const}, a) = a
ExtensibleEffects.eff_flatmap(continuation, a::Const) = a

# Either
# ------
# with this you can use Option/Try/Either as explicit handlers within `@runhandlers` calls
ExtensibleEffects.eff_applies(handler::Type{<:Either}, value::Either) = true
# eff_flatmap follows completely from Const and Identity
ExtensibleEffects.eff_pure(handler::Type{<:Either}, a) = ExtensibleEffects.eff_pure(Identity, a)  # Const would never reach this


# Iterable
# --------
ExtensibleEffects.eff_applies(handler::Type{<:Iterable}, value::Iterable) = true
# everything else follows from the generic implementations of eff_autohandler, eff_pure and eff_flatmap


# AbstractVector
# --------------
ExtensibleEffects.eff_applies(handler::Type{T}, value::T) where {T<:AbstractArray} = true
# eff_flatmap, eff_pure follow the generic implementation


# Future/Task
# -----------
ExtensibleEffects.eff_applies(handler::Type{<:Task}, value::Task) = true
ExtensibleEffects.eff_applies(handler::Type{<:Future}, value::Future) = true
# we directly interprete Task and Future
# finally surround interpreted expression by `@async`/`@spawnnat :any` to get back the Task/Future context
ExtensibleEffects.eff_pure(handler::Type{<:Union{Task, Future}}, a) = a
function ExtensibleEffects.eff_flatmap(continuation, a::Union{Task, Future})
  continuation(fetch(a))
end


# Writer
# ------
ExtensibleEffects.eff_applies(handler::Type{<:Writer}, value::Writer) = true
function ExtensibleEffects.eff_flatmap(continuation, a::Writer)
  eff_of_writer = continuation(a.value)
  map(eff_of_writer) do b
    Writer(a.acc ⊕ b.acc, b.value)
  end
end

"""
    WriteHandler(pure_accumulator=neutral)

Handler for generic Writers. The default accumulator works with Option values.
"""
struct WriterHandler{Acc}
  pure_acc::Acc
end
WriterHandler() = WriterHandler(neutral)  # same default pure-accumulator which is also used in TypeClasses
ExtensibleEffects.eff_applies(handler::WriterHandler{Acc}, value::Writer{Acc}) where Acc = true
ExtensibleEffects.eff_pure(handler::WriterHandler, value) = Writer(handler.pure_acc, value)
# autohandler and eff_flatmap are the same


# Callable
# --------

"""
    CallableHandler(args...; kwargs...)

Handler for functions, providing the arguments and keyword arguments for calling the functions.
"""
struct CallableHandler{Args, Kwargs}
  args::Args
  kwargs::Kwargs
  CallableHandler(args...; kwargs...) = new{typeof(args), typeof(kwargs)}(args, kwargs)
end
ExtensibleEffects.eff_applies(handler::CallableHandler, value::Callable) = true
# we interpret callable by adding an extra Functor from the top outside, so that internally we can interpret each call
# by just getting args and kwargs from the context
ExtensibleEffects.eff_pure(handler::CallableHandler, a) = a
function ExtensibleEffects.eff_flatmap(handler::CallableHandler, continuation, a::Callable)
  continuation(a(handler.args...; handler.kwargs...))
end

"""
    @runcallable(eff)

translates to

    Callable(function(args...; kwargs...)
      @insert_into_runhandlers CallableHandler(args...; kwargs...) eff
    end)

Thanks to `@insert_into_runhandlers` this outer runner can compose well with other outer runners.
"""
macro runcallable(expr)
  esc(:(ExtensibleEffects.TypeClasses.Callable(function(args...; kwargs...)
    ExtensibleEffects.@insert_into_runhandlers(ExtensibleEffects.CallableHandler(args...; kwargs...), $expr)
  end)))
end


# ContextManager
# --------------

"""
    ContextManagerHandler(continuation)

Handler for `DataTypesBasic.ContextManager`.

The naive handler implementation for contextmanager would immediately run the continuation within the contextmanager.
However this does not work, as handling one effect does not mean that all "inner" effects are already handled.
Hence, such a handler would actually initialize and finalize the contextmanager, without its value being
processed already. When the other "inner" effects are run later on, they would find an already destroyed
contextmanager session.
We need to make sure, that the contextmanager is really the last Effect run. Therefore we create a custom
handler.
"""
struct ContextManagerHandler{F}
  cont::F
end
# extra performance support for using Types as continuations.
ContextManagerHandler(cont) = ContextManagerHandler{Core.Typeof(cont)}(cont)

ExtensibleEffects.eff_applies(handler::ContextManagerHandler, value::ContextManager) = true
ExtensibleEffects.eff_pure(handler::ContextManagerHandler, a) = handler.cont(a)
function ExtensibleEffects.eff_flatmap(::ContextManagerHandler, continuation, c::ContextManager)
  result = c(continuation)
  @assert(result.value isa NoEffect,
    "ContextManager should be run after all other effects,"*
    " however found result `$(result)` of type $(typeof(result))")
  result
end

"""
    @runcontextmanager(eff)

translates to

    ContextManager(function(cont)
      @insert_into_runhandlers ContextManagerHandler(cont) eff
    end)

Thanks to `@insert_into_runhandlers` this outer runner can compose well with other outer runners.
"""
macro runcontextmanager(expr)
  esc(:(ExtensibleEffects.DataTypesBasic.ContextManager(function(cont)
    ExtensibleEffects.@insert_into_runhandlers(ExtensibleEffects.ContextManagerHandler(cont), $expr)
  end)))
end

"""
    @runcontextmanager_(eff)

like `@runcontextmanager(eff)`, but immediately runs the final ContextManager
"""
macro runcontextmanager_(expr)
  esc(:(
    ExtensibleEffects.@insert_into_runhandlers(ExtensibleEffects.ContextManagerHandler(Base.identity), $expr)
  ))
end


# Combine ContextManager with Vector
# ----------------------------------

"""
It happens that the plain contextmanager handler nests all found ContextManager, i.e. the first ContextManager will
only be finalized if all other ContextManagers run, even if it is completely independent of them.
For example consider
```julia
@runcontextmanager_ @syntax_eff begin
  a = [1,2,3]
  b = mycontextmanager(a)
end
```
then the execution is
```
start mycontextmanager(1)
start mycontextmanager(2)
start mycontextmanager(3)
finish mycontextmanager(3)
finish mycontextmanager(2)
finish mycontextmanager(1)
```
That is still semantically fine, however you may use ContextManager in order to save memory and really would like to
have resources released as soon as possible. So you wish to have the following execution order
```
start mycontextmanager(1)
finish mycontextmanager(1)
start mycontextmanager(2)
finish mycontextmanager(2)
finish mycontextmanager(3)
start mycontextmanager(3)
```
This is not easily possible by a mere ContextManager handler, because of several reasons. To give an intution, note
two things:
1. if you run a handler in ExtensibleEffects, it is automatically applied everywhere where possible
2. if you run a continuation, it is run until it finds the next non-run Effect, or returns the final value.

So if we just do `@runcontextmanager_` as above, it will try to evaluate the given continuation on the first
contextmanager, where the continuation itself also already run the contextmanager. Hence there is no non-run Effect left
in the continuation, and everything is run until the one final result. This results in the execution order seen above
for `@runcontextmanager_`.

To circumvent this we only have to combine the ContextManagerHandler with the Vector handler, as it is the Vector
handler, which merges all different branches into the one single continuation which makes the problems above.
If we just run both handlers at once, the continuation which is seen by the ContextManager is the continuation of the
current branch, and hence is only run until the final value of the current branch.
This corrects the execution order successfully.

The only downside is that you cannot use autorun, but you have to default to using `@syntax_eff_noautorun` and then
run your handlers manually.

IMPORTANT: As this runs the ContextManager it is crucial that all other handlers are run beforehand.
"""

"""
  ContextManagerCombinedHandler(otherhandler)

We can combine ContextManager with any other Handler. This is possible because ContextManager, within eff_flatmap,
does not constrain the returned eff of the continuation.
"""
struct ContextManagerCombinedHandler{OtherHandler, Func}
  other_handler::OtherHandler
  contextmanager_handler::ContextManagerHandler{Func}
end
function ContextManagerCombinedHandler(other_handler, func::Union{Type, Function} = identity)
  ContextManagerCombinedHandler{Core.Typeof(other_handler), Core.Typeof(func)}(other_handler, ContextManagerHandler(func))
end

function ExtensibleEffects.eff_applies(handler::ContextManagerCombinedHandler, value)
  eff_applies(handler.other_handler, value) || eff_applies(handler.contextmanager_handler, value)
end

function ExtensibleEffects.eff_pure(handler::ContextManagerCombinedHandler, a)
  b = ExtensibleEffects.eff_pure(handler.contextmanager_handler, a)
  ExtensibleEffects.eff_pure(handler.other_handler, b)
end
function ExtensibleEffects.eff_flatmap(handler::ContextManagerCombinedHandler, continuation, a)
  if eff_applies(handler.other_handler, a)
    ExtensibleEffects.eff_flatmap(handler.other_handler, continuation, a)
  elseif eff_applies(handler.contextmanager_handler, a)
    ExtensibleEffects.eff_flatmap(handler.contextmanager_handler, continuation, a)
  else
    error("ContextManagerCombinedHandler should only be eff_flatmap on values which can either be handled "*
    "by ContextManagerHandler or by other_handler = `$(handler.other_handler)`. However got value `$a`")
  end
end


# State
# -----

"""
    StateHandler(state)

Handler for running State. Gives the initial state.
"""
struct StateHandler{T}
  state::T
end
ExtensibleEffects.eff_pure(handler::StateHandler, value) = (value, handler.state)

# The updating of the state cannot be described by plain `eff_flatmap`.
# We need to define our own runhandler instead. It is a bit more complex, but still straightforward and compact.
function runhandler(handler::StateHandler, eff::Eff)
  if eff.value isa State  # eff_applies(handler, eff.value)
    nextvalue, nextstate = eff.value(handler.state)
    if isempty(eff.cont)
      _eff_pure(handler, nextvalue)
    else
      nexthandler = StateHandler(nextstate)
      runhandler(nexthandler, eff.cont(nextvalue))
    end
  else
    # standard procedure
    interpreted_continuation = if isempty(eff.cont)
      Continuation(x -> _eff_pure(handler, x))
    else
      Continuation(x -> runhandler(handler, eff.cont(x)))
    end
    Eff(eff.value, interpreted_continuation)
  end
end

"""
    @runstate eff

Note that unlike Callable, a State has to ensure that it is always the first outer Eff being run,
as it returns the inner state as an additional argument.

If you would nest it with runcallable, e.g. like `@runstate @runcallable eff` it wouldn't work,
as now the appended state is within the Callable and not directly within the State.
"""
macro runstate(expr)
  # Note, that we have to use `runhandlers` explicitly, such that other outer handlers using `@insert_into_runhandlers`
  # can interact well with this outer handler.
  esc(quote
    let eff = $expr
      isa(eff, ExtensibleEffects.Eff) || error("""
        `@runstate` only works for `Eff` type, got `$(typeof(eff))`.
        Try to use `@runstate` as you first outer handler, which is directly applied to the `Eff`.
        """)
      ExtensibleEffects.State() do state
        ExtensibleEffects.runhandlers(ExtensibleEffects.StateHandler(state), eff)
      end
    end
  end)
end
