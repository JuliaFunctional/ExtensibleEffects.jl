"""
special Wrapper, which is completely peeled of again

Comparing to Identity, Identity{T} results in Identity{T}, while NoEffect{T} results in plain T.
"""
struct NoEffect{T}
  value::T
end

"""
only for internal purposes, captures the still unevaluated part of an Eff
"""
struct Continuation{Fs}
  functions::Fs
  Continuation(functions...) = new{typeof(functions)}(functions)
end

"""
central data structure which can capture Effects in a way that they can interact, while each
is handled independently on its own
"""
struct Eff{Effectful, Fs}
  effectful::Effectful
  cont::Continuation{Fs}
end

function Eff(effectful::E, cont::Continuation{Tuple{}}) where E<:NoEffect
  # also run this if isempty(cont) to stop infinite recursion
  # (which happens otherwise because empty cont results returns noeffect for convenience)
  Eff{E, Tuple{}}(effectful, cont)
end

function Eff(effectful::NoEffect, cont::Continuation{Fs}) where Fs
  # Evaluate NoEffect directly to make sure, we don't have a chain of NoEffect function accumulating
  # e.g. with ContextManager this could lead to things not being evaluated, while the syntax suggest
  # everything is evaluated, and hence the ContextManager may finalize resource despite they are still used.
  cont(effectful.value)
end

Eff(effectful) = Eff(effectful, Continuation())

function Base.show(io::IO, eff::Eff)
  print(io, "Eff(effectful=$(eff.effectful), length(cont)=$(length(eff.cont.functions)))")
end


"""
mark a value as no effect, but plain value
"""
noeffect(value) = Eff(NoEffect(value))  # everything reduces to the Identity Monad
noeffect(eff::Eff) = eff  # if we find a Eff effect, we just directly use it (in analogy to `effect`)

"""
mark a value as an effect
"""
effect(value) = Eff(value)
effect(eff::Eff) = eff  # if we find a Eff effect, we just directly use it


# Functionalities for Continuation
# --------------------------------

function (c::Continuation{Tuple{}})(value)
  # mapping empty continuation is the same as wrapping into noeffect
  noeffect(value)
end
function (c::Continuation)(value)
  first_func = Base.first(c.functions)
  rest = Base.tail(c.functions)
  eff = first_func(value)
  Eff(eff.effectful, Continuation(eff.cont.functions..., rest...))
end

Base.isempty(c::Continuation) = Base.isempty(c.functions)
Base.map(f, c::Continuation) = Continuation(c.functions..., noeffect ∘ f)


# Functionalities for Eff
# -----------------------

TypeClasses.pure(::Type{<:Eff}, a) = noeffect(a)
TypeClasses.map(f, eff::Eff) = TypeClasses.flatmap(noeffect ∘ f, eff)
TypeClasses.flatmap(f, eff::Eff) = Eff(eff.effectful, Continuation(eff.cont.functions..., f))