struct NoEffect{T}
    value::T
end

struct Eff{Effectful, Fs}
    effectful::Effectful
    funcs::Fs
end
Eff(effectful) = Eff(effectful, ())

# immediately run continuation if there is a continuation
# and the wrapped value has no effect
function Eff(effectful::E, funcs::Tuple{}) where E<:NoEffect
    Eff{E, Tuple{}}(effectful, funcs)
end
function Eff(effectful::NoEffect, funcs::Fs) where Fs
    func = Base.first(funcs)
    rest = Base.tail(funcs)
    eff = func(effectful.value)
    Eff(eff.effectful, (eff.funcs..., rest...))
end


noeffect(value) = Eff(NoEffect(value))
noeffect(eff::Eff) = eff


using Test

e1 = noeffect(1)
e2 = noeffect(2)
curried_combine(v1) = v2 -> v1 + v2

function inference_works(e1::E1, e2::E2) where {E1, E2}
    e1_f = Eff(e1.effectful, (e1.funcs..., v1 -> noeffect(curried_combine(v1))))
    f_flatmap(f) = Eff(e2.effectful, (e2.funcs..., v2 -> noeffect(f(v2))))
    Eff(e1_f.effectful, (e1_f.funcs..., f_flatmap))
end

inference_works(e1, e2).effectful.value
@inferred inference_works(e1, e2)


function myeff_flatmap(f_flatmap::F, e1_f::E) where {F, E}
    Eff(e1_f.effectful, (e1_f.funcs..., f_flatmap))
end
which(myeff_flatmap, Tuple{Any,Any}).recursion_relation = (@nospecialize(_...)) -> true


function inference_fails(e1::E1, e2::E2) where {E1, E2}
    e1_f = myeff_flatmap(v1 -> noeffect(curried_combine(v1)), e1)
    f_flatmap(f) = myeff_flatmap(v2 -> noeffect(f(v2)), e2)
    myeff_flatmap(f_flatmap, e1_f)
end


inference_fails(e1, e2).effectful.value
@inferred inference_fails(e1, e2)
