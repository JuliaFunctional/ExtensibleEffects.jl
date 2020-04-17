using ExtensibleEffects
using DataTypesBasic
DataTypesBasic.@overwrite_Some
using TypeClasses
using Distributed

# add eff_applies for simple effects
simple_effects = (NoEffect, Option, Try, Either, Vector, ContextManager, Task, Future)
for T in simple_effects
  @eval ExtensibleEffects.eff_applies(handler::Type{<:$T}, value::$T) = true
end

# standard pure - fallback to TypeClass.pure
ExtensibleEffects.eff_pure(T, a) = TypeClasses.pure(T, a)

ExtensibleEffects.eff_pure(::Type{<:NoEffect}, a) = a
ExtensibleEffects.eff_flatmap(continuation, a::NoEffect) = continuation(a.value)

ExtensibleEffects.eff_flatmap(continuation, a::Option) = option_eff_flatmap(continuation, a)
option_eff_flatmap(continuation, a::Some) = continuation(a.value)
option_eff_flatmap(continuation, a::None) = a

ExtensibleEffects.eff_flatmap(continuation, a::Try) = try_eff_flatmap(continuation, a)
try_eff_flatmap(continuation, a::Success) = continuation(a.value)
try_eff_flatmap(continuation, a::Failure) = a

ExtensibleEffects.eff_flatmap(continuation, a::Either) = either_eff_flatmap(continuation, a)
either_eff_flatmap(continuation, a::Right) = continuation(a.value)
either_eff_flatmap(continuation, a::Left) = a

# for Vector we need to overwrite `eff_normalize_handlertype`, as the default implementation would lead `Array`
ExtensibleEffects.eff_autohandler(value::Vector) = Vector
function ExtensibleEffects.eff_flatmap(continuation, a::Vector)
  vector_of_eff_of_vector = map(continuation, a)
  eff_of_tuple_of_vector = tupled(vector_of_eff_of_vector...)
  map(flatten ∘ collect, eff_of_tuple_of_vector)
end

ExtensibleEffects.eff_pure(::Type{<:ContextManager}, a) = a
ExtensibleEffects.eff_flatmap(continuation, c::ContextManager) = c(continuation)

# we directly interprete Task and Future
ExtensibleEffects.eff_pure(::Type{<:Union{Task, Future}}, a) = a
function ExtensibleEffects.eff_flatmap(continuation, a::Union{Task, Future})
  continuation(fetch(a))
end


# Callable
# --------

struct CallWith{Args, Kwargs}
  args::Args
  kwargs::Kwargs
  CallWith(args...; kwargs...) = new{typeof(args), typeof(kwargs)}(args, kwargs)
end
ExtensibleEffects.eff_applies(handler::CallWith, value::Callable) = true
# we interpret callable by adding an extra Functor from the top outside, so that internally we can interpret each call
# by just getting args and kwargs from the context
ExtensibleEffects.eff_pure(handler::CallWith, a) = a
function ExtensibleEffects.eff_flatmap(callwith, continuation, a::Callable)
  continuation(a(callwith.args...; callwith.kwargs...))
end

"""
    runcallable(eff)
    @runcallable eff

translates to

    Callable(function(args...; kwargs...)
      @runhandlers CallWith(args...; kwargs...) eff
    end)
"""
function runcallable(eff)
  Callable(function(args...; kwargs...)
    runhandlers(ExtensibleEffects.CallWith(args...; kwargs...), eff)
  end)
end
macro runcallable(block)
  esc(:(ExtensibleEffects.runcallable($block)))
end


# Writer
# pure is only available for Acc with Neutral, hence the handler type needs to be Writer{Acc}
ExtensibleEffects.eff_applies(handler::Type{<:Writer{Acc}}, value::Writer{Acc}) where Acc = true 
ExtensibleEffects.eff_autohandler(value::Writer{Acc}) where Acc = Writer{Acc}
function ExtensibleEffects.eff_flatmap(continuation, a::Writer)
  eff_of_writer = continuation(a.value)
  map(eff_of_writer) do b
    Writer(a.acc ⊕ b.acc, b.value)
  end
end
# TODO do Writer and Iterable
