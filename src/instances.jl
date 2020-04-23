using ExtensibleEffects
using DataTypesBasic
DataTypesBasic.@overwrite_Some
using TypeClasses
using Distributed

# Generic implementations
# -----------------------

# standard pure - fallback to TypeClass.pure
ExtensibleEffects.eff_pure(T, a) = TypeClasses.pure(T, a)

# standard eff_flatmap - fallback to map, flip_types, and flatten
function ExtensibleEffects.eff_flatmap(continuation, a)
  eff_of_a_of_a = flip_types(map(continuation, a))
  map(flatten, eff_of_a_of_a)
end


# Identity/NoEffect
# -----------------
ExtensibleEffects.eff_applies(handler::Type{<:NoEffect}, value::NoEffect) = true
ExtensibleEffects.eff_pure(::Type{<:NoEffect}, a) = a
ExtensibleEffects.eff_flatmap(continuation, a::NoEffect) = continuation(a.value)

# Option
# ------
ExtensibleEffects.eff_applies(handler::Type{<:Option}, value::Option) = true
ExtensibleEffects.eff_flatmap(continuation, a::Option) = option_eff_flatmap(continuation, a)
option_eff_flatmap(continuation, a::Some) = continuation(a.value)
option_eff_flatmap(continuation, a::None) = a

# Try
# ---
ExtensibleEffects.eff_applies(handler::Type{<:Try}, value::Try) = true
ExtensibleEffects.eff_flatmap(continuation, a::Try) = try_eff_flatmap(continuation, a)
try_eff_flatmap(continuation, a::Success) = continuation(a.value)
try_eff_flatmap(continuation, a::Failure) = a

# Either
# ------
ExtensibleEffects.eff_applies(handler::Type{<:Either}, value::Either) = true
ExtensibleEffects.eff_flatmap(continuation, a::Either) = either_eff_flatmap(continuation, a)
either_eff_flatmap(continuation, a::Right) = continuation(a.value)
either_eff_flatmap(continuation, a::Left) = a

# Iterable
# --------
ExtensibleEffects.eff_applies(handler::Type{<:Iterable}, value::Iterable) = true
# everything else follows from the generic implementations of eff_autohandler, eff_pure and eff_flatmap

# Vector
# ------
ExtensibleEffects.eff_applies(handler::Type{<:Vector}, value::Vector) = true
# for Vector we need to overwrite `eff_normalize_handlertype`, as the default implementation would lead `Array`
ExtensibleEffects.eff_autohandler(value::Vector) = Vector
# eff_flatmap follows the generic implementation

# ContextManager
# --------------
ExtensibleEffects.eff_applies(handler::Type{<:ContextManager}, value::ContextManager) = true
ExtensibleEffects.eff_pure(::Type{<:ContextManager}, a) = a
ExtensibleEffects.eff_flatmap(continuation, c::ContextManager) = c(continuation)

# Future/Task
# -----------
ExtensibleEffects.eff_applies(handler::Type{<:Task}, value::Task) = true
ExtensibleEffects.eff_applies(handler::Type{<:Future}, value::Future) = true
# we directly interprete Task and Future
# finally surround interpreted expression by `@async`/`@spawnnat :any` to get back the Task/Future context
ExtensibleEffects.eff_pure(::Type{<:Union{Task, Future}}, a) = a
function ExtensibleEffects.eff_flatmap(continuation, a::Union{Task, Future})
  continuation(fetch(a))
end

# Writer
# ------
# pure is only available for Acc with Neutral, hence the handler type needs to be Writer{Acc}
ExtensibleEffects.eff_applies(handler::Type{<:Writer{Acc}}, value::Writer{Acc}) where Acc = true
ExtensibleEffects.eff_autohandler(value::Writer{Acc}) where Acc = Writer{Acc}
function ExtensibleEffects.eff_flatmap(continuation, a::Writer)
  eff_of_writer = continuation(a.value)
  map(eff_of_writer) do b
    Writer(a.acc ⊕ b.acc, b.value)
  end
end

struct WriterHandler{Acc}
  pure_acc::Acc
end
ExtensibleEffects.eff_applies(handler::WriterHandler{Acc}, value::Writer{Acc}) where Acc = true
ExtensibleEffects.eff_pure(handler::WriterHandler, value) = Writer(handler.pure_acc, value)
# autohandler and eff_flatmap are the same


# Callable
# --------

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
  esc(:(Callable(function(args...; kwargs...)
    ExtensibleEffects.@insert_into_runhandlers(ExtensibleEffects.CallableHandler(args...; kwargs...), $expr)
  end)))
end


# State
# -----

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
    eff = $expr
    isa(eff, Eff) || error("""
      `@runstate` only works for `Eff` type, got `$(typeof(eff))`.
      Try to use `@runstate` as you first outer handler, which is directly applied to the `Eff`.
      """)
    ExtensibleEffects.State() do state
      ExtensibleEffects.runhandlers(ExtensibleEffects.StateHandler(state), eff)
    end
  end)
end
