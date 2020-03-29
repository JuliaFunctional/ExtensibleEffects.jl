module ExtensibleEffects
export Continuation, NoEffect, Eff, noeffect, effect, runeffect, runlast, @syntax_eff, @syntax_eff_run
using TypeClasses
using SimpleMatch
using Monadic
struct Continuation{Fs}
  functions::Fs
  Continuation(functions...) = new{typeof(functions)}(functions)
end

struct Eff{Effectful, Fs}
  value::Effectful
  cont::Continuation{Fs}
end
Eff(value) = Eff(value, Continuation())

struct NoEffect{T}
  value::T
end

"""
mark a value as no effect, but plain value
"""
noeffect(value) = Eff(NoEffect(value))

"""
mark a value as an effect
"""
effect(value) = Eff(value)

function (c::Continuation)(value)
  if isempty(c)
    noeffect(value)  # TODO Recursion?
  else
    first = c.functions[1]
    rest = c.functions[2:end]
    eff = first(value)
    @match(eff.value, eff.cont) do f
      f(pure::NoEffect, c2) = Continuation(c2.functions..., rest...)(pure.value)
      f(effectful, c2) = Eff(effectful, Continuation(c2.functions..., rest...))
    end
  end
end
# Functionalities for Continuation
Base.isempty(c::Continuation) = Base.isempty(c.functions)
Base.map(f, c::Continuation) = TypeClasses.map(f, c)
TypeClasses.map(f, c::Continuation) = Continuation(c.functions..., noeffect ∘ f)

# Functionalities for Eff
TypeClasses.pure(::Type{<:Eff}, a) = noeffect(a)
Base.map(f, eff::Eff) = TypeClasses.map(f, eff)
function TypeClasses.map(f, eff::Eff)
  @match(eff.value) do h
    h(v::NoEffect) = noeffect(f(v))
    h(v) = Eff(v, Continuation(eff.cont.functions..., noeffect ∘ f))  # same as Base.map(f, eff.cont)
  end
end
function TypeClasses.flatmap(f, eff::Eff)
  @match(eff.value) do h
    h(v::NoEffect) = f(v)
    h(v) = Eff(v, Continuation(eff.cont.functions..., f))
  end
end
TypeClasses.flatten(eff::Eff) = TypeClasses.flatmap(identity, eff)
# there is probably a more efficient version, but this should be fine for now
TypeClasses.ap(ff::Eff, fa::Eff) = TypeClasses.default_ap(ff, fa)

"""
extract final value from Eff with all effects already run
"""
function runlast(eff::Eff)
  if isempty(eff.cont)
    @match(eff.value) do f
      f(value::NoEffect) = value.value
      f(forgotteneffect) = error("not all effects have been handled, found $forgotteneffect")
    end
  else
    @match(eff.value) do f
      f(noeffect::NoEffect) = runlast(eff.cont(noeffect.value))
      f(forgotteneffect) = error("not all effects have been handled, found $forgotteneffect")
    end
  end
end

"""
convenience wrapper to better use runeffect in |>
"""
runeffect(handler) = eff -> runeffect(handler, eff)

"""
key method to run an effect on some effecthandler Eff

note that we represent effectrunners as plain types in order to associate
standard effect runners with types like Vector, Option, ...
"""
function runeffect(handler, eff::Eff)
  if isempty(eff.cont)
    @match(eff.value) do f
      # pure leaf case
      f(pure::NoEffect) = _eff_pure(handler, pure.value)
      # effectful state with empty continuation should be isomorphic to effectful state with Continuation(noeffect)
      function f(effectful)
        # Continuation(x -> runeffect(EffType, eff.cont(x)))
        # == Continuation(x -> runeffect(EffType, noeffect(x))), because isempty(eff.cont)
        # == Continuation(x -> _eff_pure(EffType, x))
        interpreted_continuation = Continuation(x -> _eff_pure(handler, x))
        _eff_flatmap(handler, interpreted_continuation, eff.value)
      end
    end
  else
    # TODO can this be rewritten as an append?
    interpreted_continuation = Continuation(x -> runeffect(handler, eff.cont(x)))
    _eff_flatmap(handler, interpreted_continuation, eff.value)
  end
end

"""
  _eff_flatmap(...)

checks whether the current value matches the current effect.
If so, it calls `eff_flatmap`, if not, it knows what to do.
"""
function _eff_flatmap(handler, interpreted_continuation::Continuation, value)
  if eff_applies(handler, value)
    # current value matches current effect-handler
    result = eff_flatmap(handler, interpreted_continuation, value)
    # provide convenience wrapper if someone forgets to return an Eff
    isa(result, Eff) ? result : noeffect(result)
  else
    # current value does not match current effect-handler
    Eff(value, interpreted_continuation)
  end
end
eff_applies(handler::Type{T}, value::T) where T = true
eff_applies(handler::Type{T}, value::Other) where {T, Other} = false


function _eff_pure(handler, value)
  result = eff_pure(handler, value)
  isa(result, Eff) ? result : noeffect(result)
end

"""
    eff_pure(handler, value)::Union{handledtype, Eff}

Overwrite this for your custom effect handler, return either EffType or an Eff.
"""
function eff_pure end
"""
    eff_flatmap(continuation, value::EffType)::Union{EffType, Eff}

Overwrite this for your custom effect handler, return either EffType or an Eff.
"""
function eff_flatmap end
"""
for combining multiple effects it is very handy to dispatch on EffType for Union{EffType1, EffType2}

however for standard effects we can ommit EffType, as we now it by typeof(value)
"""
eff_flatmap(handler, interpreted_continuation::Continuation, value) = eff_flatmap(interpreted_continuation, value)


# include some standard effects:
# ==============================
include("effects_instances.jl")



# eff syntax
# ==========

macro syntax_eff(block::Expr)
  block = macroexpand(__module__, block)
  esc(syntax_eff(block))
end
macro syntax_eff(wrapper, block::Expr)
  block = macroexpand(__module__, block)
  esc(syntax_eff(block, wrapper))
end
macro syntax_eff_run(effecthandlers, block::Expr)
  block = macroexpand(__module__, block)
  vareff, effect_handling = _build_runeffect_expr(effecthandlers)
  esc(quote
    $vareff = $(syntax_eff(block))
    $effect_handling
  end)
end
macro syntax_eff_run(effecthandlers, wrapper, block::Expr)
  block = macroexpand(__module__, block)
  vareff, effect_handling = _build_runeffect_expr(effecthandlers)
  esc(quote
    $vareff = $(syntax_eff(block, wrapper))
    $effect_handling
  end)
end

function syntax_eff(block::Expr)
  monadic(
    :(ExtensibleEffects.TypeClasses.map),
    :(ExtensibleEffects.TypeClasses.flatmap),
    :(ExtensibleEffects.effect),
    block)
end
function syntax_eff(block::Expr, extra_wrapper)
  monadic(
    :(ExtensibleEffects.TypeClasses.map),
    :(ExtensibleEffects.TypeClasses.flatmap),
    :(ExtensibleEffects.effect ∘ $extra_wrapper),
    block)
end

function _build_runeffect_expr(effecthandlers)
  # create a variable in which we assume to get the result of the syntax_eff
  @gensym vareff
  if effecthandlers isa Expr && effecthandlers.head === :tuple
    # extract tuple directly to have better typeinference
    effect_handling = Base.foldr(effecthandlers.args, init = vareff) do x, acc
      :($acc |> ExtensibleEffects.runeffect($x))
    end
    effect_handling_last = :($effect_handling |> ExtensibleEffects.runlast)
    # return the variable as well as the effect handling
    vareff, effect_handling_last
  else
    # treat effecthandlers at runtime
    # return the variable as well as the effect handling
    vareff, quote
      (Base.foldr($effecthandlers, init = $vareff) do x, acc
        acc |> ExtensibleEffects.runeffect(x)
      end) |> ExtensibleEffects.runlast
    end
  end
end



end # module
