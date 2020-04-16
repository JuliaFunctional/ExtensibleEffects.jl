using ExtensibleEffects
using DataTypesBasic
DataTypesBasic.@overwrite_Base
using TypeClasses
TypeClasses.@overwrite_Base

# add eff_applies for simple effects
const simple_effects = Union{NoEffect, Option, Try, Either, Vector, ContextManager, Task, Future}
ExtensibleEffects.eff_applies(handler::Type{<:T}, value::T) where {T <: simple_effects} = true

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

function ExtensibleEffects.eff_flatmap(continuation, a::Vector)
  vector_of_eff_of_vector = map(continuation, a)
  eff_of_tuple_of_vector = tupled(vector_of_eff_of_vector...)
  map(flatten ∘ collect, eff_of_tuple_of_vector)
end

ExtensibleEffects.eff_pure(::Type{<:ContextManager}, a) = a
ExtensibleEffects.eff_flatmap(continuation, c::ContextManager) = c(continuation)

# we directly interprete Task and Future
ExtensibleEffects.eff_pure(::Type{<:Union{Task, Future}, a) = a
function ExtensibleEffects.eff_flatmap(continuation, a::Union{Task, Future}, context)
  continuation(fetch(a))
end


struct CallWith{Args, Kwargs}
  args::Args
  kwargs::Kwargs
end
ExtensibleEffects.eff_applies(handler::Type{<:CallWith}, value::Callable) = true
# we interpret callable by adding an extra Functor from the top outside, so that internally we can interpret each call
# by just getting args and kwargs from the context
ExtensibleEffects.eff_pure(::Type{<:Callable}, a) = a
function ExtensibleEffects.eff_flatmap(continuation, a::Callable, context)
  args, kwargs = context(Callable)
  continuation(a(args...; kwargs...))
end
