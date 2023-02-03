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
  # Continuation(functions...) = new{typeof(functions)}(functions)
  Continuation() = new{Tuple{}}(())
  Continuation(fs::T) where {T<:Tuple} = new{T}(fs)
  Continuation(f::F) where {F} = new{Tuple{Core.Typeof(f)}}((f,))
end

function ifemptyelse(c::Continuation{Tuple{}}, p, q)
  @assert isempty(c)
  p
end

function ifemptyelse(c::Continuation, p, q) 
  @assert !isempty(c)
  q
end

"""
central data structure which can capture Effects in a way that they can interact, while each
is handled independently on its own
"""
struct Eff{Effectful, Fs}
  effectful::Effectful
  cont::Continuation{Fs}

  function Eff(effectful::T, cont::Continuation{Tuple{}}) where {T}
      # also run this if isempty(cont) to stop infinite recursion
      # (which happens otherwise because empty cont results returns noeffect for convenience)
      new{T, Tuple{}}(effectful, cont)
  end
  function Eff(effectful::T, cont::Continuation{Fs}) where {T, Fs}
    if effectful isa NoEffect
      # Evaluate NoEffect directly to make sure, we don't have a chain of NoEffect function accumulating
      # e.g. with ContextManager this could lead to things not being evaluated, while the syntax suggest
      # everything is evaluated, and hence the ContextManager may finalize resource despite they are still used.
      cont(effectful.value)

    else
      # also run this if isempty(cont) to stop infinite recursion
      # (which happens otherwise because empty cont results returns noeffect for convenience)
      new{T, Fs}(effectful, cont)
    end
  end
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
    noeffect(value)
end

function (c::Continuation)(value)
    first_func = first(c.functions)
    rest = Base.tail(c.functions)
    eff = first_func(value)
    Eff(eff.effectful, Continuation((eff.cont.functions..., rest...)))
end

Base.isempty(c::Continuation{Tuple{}}) = true
Base.isempty(::Continuation) = false

Base.map(f, c::Continuation) = Continuation((c.functions..., noeffect ∘ f))


# Functionalities for Eff
# -----------------------

TypeClasses.pure(::Type{<:Eff}, a) = noeffect(a)
TypeClasses.map(f, eff::Eff) = TypeClasses.flatmap(noeffect ∘ f, eff)
TypeClasses.flatmap(f, eff::Eff) = Eff(eff.effectful, Continuation((eff.cont.functions..., f)))