using ExtensibleEffects
using DataTypesBasic
DataTypesBasic.@overwrite_Base
using TypeClasses
TypeClasses.@overwrite_Base

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
  eff_of_vector_of_vector = tupled(map(continuation, a)...)
  map(flatten ∘ collect, eff_of_vector_of_vector)
end

ExtensibleEffects.eff_pure(::Type{<:ContextManager}, a) = a
ExtensibleEffects.eff_flatmap(continuation, c::ContextManager) = c(continuation)
