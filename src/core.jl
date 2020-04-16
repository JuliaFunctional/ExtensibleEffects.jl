using TypeClasses
using DataTypesBasic


struct Continuation{Fs}
  functions::Fs
  Continuation(functions...) = new{typeof(functions)}(functions)
end

struct Eff{Effectful, Fs}
  value::Effectful
  cont::Continuation{Fs}
end
Eff(value) = Eff(value, Continuation())

function Base.show(io::IO, eff::Eff)
  print(io, "Eff(value=$(eff.value), length(cont)=$(length(eff.cont.functions)))")
end

# We reuse the Identity Monad from DataTypesBasic here, but give it a more expressive name
const NoEffect = Identity

"""
mark a value as no effect, but plain value
"""
noeffect(value) = Eff(NoEffect(value))

"""
mark a value as an effect
"""
effect(value) = Eff(value)


# Functionalities for Continuation
# --------------------------------

function (c::Continuation)(value)
  if isempty(c)
    noeffect(value)  # TODO Recursion?
  else
    first_func = c.functions[1]
    rest = c.functions[2:end]
    eff = first_func(value)
    Eff(eff.value, Continuation(eff.cont.functions..., rest...))
  end
end
Base.isempty(c::Continuation) = Base.isempty(c.functions)
Base.map(f, c::Continuation) = Continuation(c.functions..., noeffect ∘ f)


# Functionalities for Eff
# -----------------------

TypeClasses.pure(::Type{<:Eff}, a) = noeffect(a)
function Base.map(f, eff::Eff)
  TypeClasses.flatmap(noeffect ∘ f, eff)
end
function TypeClasses.flatmap(f, eff::Eff)
  Eff(eff.value, Continuation(eff.cont.functions..., f))
end
TypeClasses.flatten(eff::Eff) = TypeClasses.flatmap(identity, eff)
# there is probably a more efficient version, but this should be fine for now
TypeClasses.ap(ff::Eff, fa::Eff) = TypeClasses.default_ap_having_map_flatmap(ff, fa)
