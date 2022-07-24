using ExtensibleEffects
using TypeClasses
using Test

continuation(x) = noeffect([x])

vector_of_eff_of_vector = map(continuation, [1, 20])
e1 = vector_of_eff_of_vector[1]
e2 = vector_of_eff_of_vector[2]

mygoal(e1, e2) = @syntax_flatmap begin
    v1 = e1
    v2 = e2
    @pure [v1; v2]
end

mygoal(e1, e2)
@inferred mygoal(e1, e2)
@code_warntype mygoal(e1, e2)

function test_fails(e1, e2)
    combine(v1, v2) = [v1; v2]
    curried_combine(v1) = v2 -> combine(v1, v2)
    
    e1_f = map(curried_combine, e1)
    f_flatmap(f) = TypeClasses.map(v2 -> f(v2), e2)
    TypeClasses.flatmap(f_flatmap, e1_f)
end

@inferred test_fails(e1, e2)
@code_warntype test_fails(e1, e2)

function prepare_test(e1, e2)
    combine(v1, v2) = [v1; v2]
    curried_combine(v1) = v2 -> combine(v1, v2)
    
    e1_f = map(curried_combine, e1)
    f_flatmap(f) = TypeClasses.map(v2 -> f(v2), e2)
    f_flatmap, e1_f
end

f_flatmap, e1_f = prepare_test(e1, e2)
@inferred TypeClasses.flatmap(f_flatmap, e1_f)

function test_infers(e1, e2)
    f_flatmap, e1_f = prepare_test(e1, e2)
    TypeClasses.flatmap(f_flatmap, e1_f)
end

@inferred test_infers(e1, e2)



# ---------


function prepare_test(::Type{T}, a1, a2) where T
    function func(acc′, c)
        acc′ ⊕ pure(T, c)  # combining on T
    end

    function curried_func(a1)
        #= /home/ssahm/.julia/dev/TypeClasses/src/TypeClasses/FunctorApplicativeMonad.jl:167 =#
        a2 -> func(a1, a2)
    end
    
    ap1 = map(curried_func, a1)
    ap2 = a2

    f_flatmap(f) = TypeClasses.map(ap2) do a
        f(a)
    end
    return f_flatmap, ap1
end

# infers
f_flatmap, ap1 = prepare_test(T, a1, a2)
@inferred TypeClasses.flatmap(f_flatmap, ap1)

function test_infers(::Type{T}, a1, a2) where T
    f_flatmap, ap1 = prepare_test(T, a1, a2)
    TypeClasses.flatmap(f_flatmap, ap1)
end

@inferred test_infers(T, a1, a2)

function test_fails(::Type{T}, a1, a2) where T
    function func(acc′, c)
        acc′ ⊕ pure(T, c)  # combining on T
    end

    function curried_func(a1)
        #= /home/ssahm/.julia/dev/TypeClasses/src/TypeClasses/FunctorApplicativeMonad.jl:167 =#
        a2 -> func(a1, a2)
    end
    
    ap1 = map(curried_func, a1)
    ap2 = a2

    f_flatmap(f) = TypeClasses.map(ap2) do a
        f(a)
    end

    TypeClasses.flatmap(f_flatmap, ap1)
end


@inferred test_fails(T, a1, a2)
@code_warntype test_fails(T, a1, a2)




using TypeClasses
using ExtensibleEffects

myarray = collect(1:100)
@inferred TypeClasses.flatmap(x -> noeffect([x, x, x]), noeffect(myarray))

this_infers(f, a) = TypeClasses.flatmap(f, a)
@inferred this_infers(x -> noeffect([x, x, x]), noeffect(myarray))

function this_infers_too(array)
    myflatmap(x) = noeffect([x, x, x])
    TypeClasses.flatmap(myflatmap, noeffect(array))
end
@inferred this_infers_too(array1)
@code_warntype this_infers_too(array1)