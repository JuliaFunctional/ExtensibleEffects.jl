using ExtensibleEffects
using ExtensibleEffects: runhandler, Continuation, Eff, _eff_pure, @specializetype, myeff_flatmap, myeff_flatmap2
using TypeClasses
using BenchmarkTools
using JET

array1 = collect(1:100)

program1 = @syntax_eff_noautorun begin
    x = array1
    [x, x, x]
end

runhandlers(Vector, program1)

@code_warntype runhandlers(Vector, program1.cont(1))
@code_warntype runhandler(Vector, program1.cont(1))
@benchmark runhandlers(Vector, program1)

function test(handler, eff)
    continuation = if isempty(eff.cont)
        # you may think we could simplify this, however for eff `eff_flatmap(handler, x -> eff_pure(handler,  x), eff) != eff` 
        # because there is the handler which may have extra information
        @specializetype handler Continuation(x -> ExtensibleEffects._eff_pure(handler, x))
    else
        @specializetype handler Continuation(x -> ExtensibleEffects.runhandler(handler, eff.cont(x)))
    end

    a = eff.effectful
    a_of_eff_of_a = map(continuation, a)
    # eff_of_a_of_a = flip_types(a_of_eff_of_a)
    # eff_of_a = map(flatten, eff_of_a_of_a)
    # eff_of_a
end

const a_of_eff_of_a = test(Vector, program1.cont(1))
@code_warntype TypeClasses.default_flip_types_having_pure_combine_apEltype(a_of_eff_of_a)

iter = a_of_eff_of_a
T = typeof(iter)
b, state = iterate(iter)
start = map(c -> pure(T, c), b)  # we can only combine on ABC

b2, state2 = iterate(iter, state)

mapn(start, b2) do acc′, c  # working in applicative context B
    acc′ ⊕ pure(T, c)  # combining on T
end

@code_warntype mapn(start, b2) do acc′, c  # working in applicative context B
    acc′ ⊕ pure(T, c)  # combining on T
end

struct EffWithEltype2{ElType, E}
    eff::E
end
eff_mark_eltype(eltype, eff) = EffWithEltype2{eltype, typeof(eff)}(eff)
eff_mark_eltype(::Type{eltype}) where eltype = eff -> eff_mark_eltype(eltype, eff)

Base.IteratorEltype(::EffWithEltype2) = Iterators.HasEltype()
Base.eltype(::EffWithEltype2{ElType}) where ElType = ElType 

@code_warntype eff_mark_eltype(Vector, eff)
@code_warntype map(eff_mark_eltype(Vector), a_of_eff_of_a)

new_a_of_eff_of_a = map(eff_mark_eltype(Vector), a_of_eff_of_a)

map(EL -> NEW)

Base.foldl(Iterators.rest(iter, state); init = start) do acc, b
    mapn(acc, b) do acc′, c  # working in applicative context B
        acc′ ⊕ pure(T, c)  # combining on T
    end
end

@code_warntype Base.foldl(Iterators.rest(iter, state); init = start) do acc, b
    mapn(acc, b) do acc′, c  # working in applicative context B
        acc′ ⊕ pure(T, c)  # combining on T
    end
end

@which Base.foldl(Iterators.rest(iter, state); init = start) do acc, b
    mapn(acc, b) do acc′, c  # working in applicative context B
        acc′ ⊕ pure(T, c)  # combining on T
    end
end


function _foldl_impl(op::OP, init, itr) where {OP}
    # Unroll the while loop once; if init is known, the call to op may
    # be evaluated at compile time
    y = iterate(itr)
    y === nothing && return init
    v = op(init, y[1])
    while true
        y = iterate(itr, y[2])
        y === nothing && break
        v = op(v, y[1])
    end
    return v
end

_foldl_impl(start, Iterators.rest(iter, state)) do acc, b
    mapn(acc, b) do acc′, c  # working in applicative context B
        acc′ ⊕ pure(T, c)  # combining on T
    end
end

test5(T) = @code_warntype _foldl_impl(start, Iterators.rest(iter, state)) do acc, b
    mapn(acc, b) do acc′, c  # working in applicative context B
        acc′ ⊕ pure(T, c)  # combining on T
    end
end
test5(T)



function _foldl_3(op::OP, init, itr) where {OP}
    # Unroll the while loop once; if init is known, the call to op may
    # be evaluated at compile time
    y = iterate(itr)
    y === nothing && return init
    v = op(init, y[1])
    
    y = iterate(itr, y[2])
    y === nothing && return v
    v = op(v, y[1])

    y = iterate(itr, y[2])
    y === nothing && return v
    v = op(v, y[1])

    return v
end

_foldl_3(start, Iterators.rest(iter, state)) do acc, b
    mapn(acc, b) do acc′, c  # working in applicative context B
        acc′ ⊕ pure(Vector, c)  # combining on T
    end
end

@code_warntype _foldl_3(start, Iterators.rest(iter, state)) do acc, b
    mapn(acc, b) do acc′, c  # working in applicative context B
        acc′ ⊕ pure(T, c)  # combining on T
    end
end


function _foldl_fulltype(op::OP, init, itr, state...) where {OP}
    # Unroll the while loop once; if init is known, the call to op may
    # be evaluated at compile time
    y = iterate(itr, state...)
    y === nothing && return init
    v = op(init, y[1])
    return _foldl_fulltype(op, v, itr, y[2])
end

_foldl_fulltype(start, Iterators.rest(iter, state)) do acc, b
    mapn(acc, b) do acc′, c  # working in applicative context B
        acc′ ⊕ pure(Vector, c)  # combining on T
    end
end

@code_warntype _foldl_fulltype(start, Iterators.rest(iter, state)) do acc, b
    mapn(acc, b) do acc′, c  # working in applicative context B
        acc′ ⊕ pure(Vector, c)  # combining on T
    end
end

function op(::Val{A}, ::Val{B}) where {A, B}
    Val(A + B)
end

@code_warntype _foldl_fulltype(op, Val(0), (Val(1), Val(2), Val(3)))




@which mapn(start, b2) do acc′, c  # working in applicative context B
    acc′ ⊕ pure(T, c)  # combining on T
end

a1 = start
a2 = b2

myflatmap2(f, eff::Eff) = Eff(eff.effectful, Continuation(eff.cont.functions..., f))

function test3(::Type{T}, a1, a2) where T
    function func(acc′, c)
        acc′ ⊕ pure(T, c)  # combining on T
    end

    function curried_func(a1)
        #= /home/ssahm/.julia/dev/TypeClasses/src/TypeClasses/FunctorApplicativeMonad.jl:167 =#
        a2 -> func(a1, a2)
    end
    
    ap1 = map(curried_func, a1)
    ap2 = a2

    # @syntax_flatmap begin
    #     f = ap1
    #     a = ap2
    #     @pure f(a)
    # end

    # TypeClasses.flatmap(ap1) do f
    #     TypeClasses.map(ap2) do a
    #         f(a)
    #     end
    # end

    f_flatmap(f) = TypeClasses.map(ap2) do a
        f(a)
    end

    TypeClasses.flatmap(f_flatmap, ap1)

    myeff_flatmap(f_flatmap, ap1)
    
    # myflatmap2(f_flatmap, ap1)
    

    # myflatmap(f, eff::Eff) = Eff(eff.effectful, Continuation(eff.cont.functions..., f))
    # myflatmap(f_flatmap, ap1)
    
    
    
    # eff = ap1
    # f = f_flatmap
    # Eff(eff.effectful, Continuation(eff.cont.functions..., f))

    # f_flatmap(curried_func([1]))

    # TypeClasses.map(ap2) do a
    #     curried_func([1])(a)
    # end

    # TypeClasses.map(ap2) do a
    #     func([1], a)
    # end
    # f = curried_func([1])
    # TypeClasses.flatmap(noeffect ∘ f, ap2)
end

@code_warntype test3(T, a1, a2)
@report_opt test3(T, a1, a2)

map(curried_func, a1)
#= /home/ssahm/.julia/dev/ExtensibleEffects/test/benchmarks.jl:67 =#
@code_warntype ap(map(curried_func, a1), a2)
ap1 = map(curried_func, a1)
ap2 = a2

@macroexpand @syntax_flatmap begin
    f = ap1
    a = ap2
    @pure f(a)
end

test2(ap1, ap2) = TypeClasses.flatmap(ap1) do f
    TypeClasses.map(ap2) do a
        f(a)
    end
end
@code_warntype test2(ap1, ap2) 

create_fflatmap(ap2) = f -> TypeClasses.map(ap2) do a
    f(a)
end

f_flatmap2 = create_fflatmap(ap2)
@report_opt f_flatmap2(curried_func([1]))



myflatmap1(f::F, eff::Eff) where F = Eff(eff.effectful, Continuation(eff.cont.functions..., f))
myflatmap3(f, eff::Eff) = Eff(eff.effectful, Continuation(eff.cont.functions..., f))

@code_warntype myflatmap1(f_flatmap2, ap1)

effectful = ap1.effectful
cont = Continuation(ap1.cont.functions..., f_flatmap2)

@code_warntype Eff(effectful, cont)

@which Eff(effectful, cont)

@code_warntype cont(effectful)
cont(effectful)
function makecont1(c::Continuation, value)
    first_func = Base.first(c.functions)
    rest = Base.tail(c.functions)
    eff = first_func(value)
    Eff(eff.effectful, Continuation(eff.cont.functions..., rest...))
end
@code_warntype makecont1(cont, effectful)




function makecont2(c::Continuation, value)
    first_func = Base.first(c.functions)
    rest = Base.tail(c.functions)
    _makecont2(first_func(value), rest)
end
function _makecont2(eff, rest)
    Eff(eff.effectful, Continuation(eff.cont.functions..., rest...))
end
@code_warntype makecont2(cont, effectful)


function makecont3(c::Continuation, value)
    first_func = Base.first(c.functions)
    # rest = Base.tail(c.functions)
    first_func(value)
end
@code_warntype makecont3(cont, effectful)

cont2 = Continuation(identity)

@code_warntype makecont3(cont2, 2)
@code_warntype f_flatmap2(effectful)

@code_warntype TypeClasses.map(ap2) do a
    a .+ 2
end

@which TypeClasses.flatmap(ap1) do f
    TypeClasses.map(ap2) do a
        f(a)
    end
end


function mapn_code(N)
    func_name = :func
    args_symbols = Symbol.(:a, 1:N)
    curried_func_name = :curried_func
    curried_func_expr = TypeClasses._create_curried_expr(func_name, N)
    ap_expr = TypeClasses._create_ap_expr(curried_func_name, args_symbols)
    :(function mapn($func_name, $(args_symbols...))
        $curried_func_name = $curried_func_expr
        $ap_expr
    end)
end

function map2(func, a1, a2)
    #= /home/ssahm/.julia/dev/ExtensibleEffects/test/benchmarks.jl:65 =#
    #= /home/ssahm/.julia/dev/ExtensibleEffects/test/benchmarks.jl:66 =#
    curried_func = (a1->begin
                #= /home/ssahm/.julia/dev/TypeClasses/src/TypeClasses/FunctorApplicativeMonad.jl:167 =#
                a2->begin
                        #= /home/ssahm/.julia/dev/TypeClasses/src/TypeClasses/FunctorApplicativeMonad.jl:167 =#
                        func(a1, a2)
                    end
            end)
    #= /home/ssahm/.julia/dev/ExtensibleEffects/test/benchmarks.jl:67 =#
    ap(map(curried_func, a1), a2)
end

mapn_code(2)



singleton_array(T::Type{<:AbstractArray}, a) = convert(T, [a]) 

struct ChainedFunctions{Fs}
    functions::Fs
    ChainedFunctions(functions...) = new{typeof(functions)}(functions)
end

function singleton_wrapper1(type, value)
    continuation = ChainedFunctions(x -> singleton_array(type, x))
    first_func = Base.first(continuation.functions)
    first_func(value)
end

function singleton_wrapper2(type::T, value) where T
    continuation = ChainedFunctions(x -> singleton_array(type, x))
    first_func = Base.first(continuation.functions)
    first_func(value)
end

function singleton_wrapper3(::Type{type}, value) where type
    continuation = ChainedFunctions(x -> singleton_array(type, x))
    first_func = Base.first(continuation.functions)
    first_func(value)
end

function singleton_wrapper4(type::Union{Type{T}, Any}, value) where T
    continuation = ChainedFunctions(x -> singleton_array(type, x))
    first_func = Base.first(continuation.functions)
    first_func(value)
end


function singleton_wrapper1_wrapper1(::Type{type}, value) where type
    singleton_wrapper1(type, value)
end
function singleton_wrapper1_wrapper1(type, value)
    singleton_wrapper1(type, value)
end

using SimpleMatch
function singleton_wrapper1_wrapper2(type, value)
    @match(type) do f
        f(::Type{T}) where T = singleton_wrapper1(T, value)
        f(_) = singleton_wrapper1(type, value)
    end
end

@inline function singleton_wrapper1_wrapper3(::Type{type}, value) where type
    singleton_wrapper1(type, value)
end
@inline function singleton_wrapper1_wrapper3(type, value)
    singleton_wrapper1(type, value)
end

using Test
@inferred singleton_wrapper1(Vector, 1)
@inferred singleton_wrapper2(Vector, 1)
@inferred singleton_wrapper3(Vector, 1)
@inferred singleton_wrapper4(Vector, 1)
@inferred singleton_wrapper1_wrapper1(Vector, 1)
@inferred singleton_wrapper1_wrapper2(Vector, 1)
@inferred singleton_wrapper1_wrapper3(Vector, 1)


struct ChainedFunctions{Fs}
    functions::Fs
    ChainedFunctions(functions...) = new{typeof(functions)}(functions)
end

instantiate(T) = T()

function instantiate_wrapper1(type)
    continuation = ChainedFunctions(() -> instantiate(type))
    first_func = Base.first(continuation.functions)
    first_func()
end

function instantiate_wrapper2(type::T) where T
    continuation = ChainedFunctions(() -> instantiate(type))
    first_func = Base.first(continuation.functions)
    first_func()
end

function instantiate_wrapper3(::Type{type}) where type
    continuation = ChainedFunctions(() -> instantiate(type))
    first_func = Base.first(continuation.functions)
    first_func()
end

function instantiate_wrapper4(type::Union{Type{T}, Any}) where T
    continuation = ChainedFunctions(() -> instantiate(type))
    first_func = Base.first(continuation.functions)
    first_func()
end


function instantiate_wrapper1_wrapper1(::Type{type}) where type
    instantiate_wrapper1(type)
end
function instantiate_wrapper1_wrapper1(type)
    instantiate_wrapper1(type)
end


f() = 4
using Test
@inferred instantiate_wrapper1(Vector)
@inferred instantiate_wrapper2(Vector)
@inferred instantiate_wrapper3(Vector)
@inferred instantiate_wrapper4(Vector)
@inferred instantiate_wrapper1_wrapper1(Vector)


struct ChainedFunctions{Fs}
    functions::Fs
    ChainedFunctions(functions...) = new{typeof(functions)}(functions)
end

myconvert(T, value) = T(value)

function myconvert_wrapper(type, value)
    continuation = ChainedFunctions(x -> myconvert(type, x))
    first_func = Base.first(continuation.functions)
    first_func(value)
end


using Test
tostring(a) = "$a"
@inferred myconvert_wrapper(tostring, 1)
# "1"

@inferred myconvert_wrapper(Symbol, 1)
# ERROR: return type Symbol does not match inferred return type Any


struct ChainedFunctions{Fs}
    functions::Fs
    ChainedFunctions(functions...) = new{typeof(functions)}(functions)
end

fs = ChainedFunctions(identity)



function callfirst(c::ChainedFunctions, value)
    first_func = Base.first(c.functions)
    # rest = Base.tail(c.functions)
    first_func(value)

    # Eff(eff.effectful, Continuation(eff.cont.functions..., rest...))
end

@code_warntype callfirst(fs, 1)





f(a) = isodd(a) ? Symbol(a) : "$a"
A = [1,2,3,4]
map(f, A)

@which eltype(typeof(Base.Generator(f, A)))
Base.collect_similar(A, Generator(f,A))

g(a) = Symbol(a)
@which eltype(typeof(Base.Generator(g, A)))

eltype(typeof(Base.Generator(g, A)))


Base.collect_similar(A, Base.Generator(g, A))

iterator = Base.Generator(g, A)
Iterators.IteratorEltype(iterator)

a = Base.@default_eltype iterator

@which map(g, A)



myconvert(T, value) = T(value)

function outerfunc1(type, value)
    innerfunc(x) = myconvert(type, x)
    innerfunc(value)
end
function outerfunc2(type::T, value) where T
    innerfunc(x) = myconvert(type, x)
    innerfunc(value)
end
function outerfunc3(::Type{type}, value) where type
    innerfunc(x) = myconvert(type, x)
    innerfunc(value)
end

using Test
tostring(a) = "$a"

@inferred outerfunc1(tostring, 1) # "1"
@inferred outerfunc2(tostring, 1) # "1"
@inferred outerfunc3(tostring, 1) # MethodError

@inferred outerfunc1(Symbol, 1) # ERROR: return type Symbol does not match inferred return type Any
@inferred outerfunc2(Symbol, 1) # ERROR: return type Symbol does not match inferred return type Any
@inferred outerfunc3(Symbol, 1) # Symbol(1)