using Test
using ExtensibleEffects
using DataTypesBasic
using TypeClasses
using Suppressor
splitln(str) = split(strip(str), "\n")

program2 = @syntax_eff_noautorun begin
  r0 = @Try 4
  r1 = iftrue(r0 % 4 == 0, r0 + 1)
  r2 = @Try r1
  r3 = Option(r2)
  Option(r3)
  ## same as
  # ```
  # r4 = Option(r3)
  # @pure r4
  # ```
  ## same as
  # ```
  # r4 = Option(r3)
  # noeffect(4)
  # ```
end
r2_1 = runhandlers((Identity, Const, Nothing), program2)
@test r2_1 == 5
@test autorun(program2) === 5


r2_1_flatmap = @syntax_flatmap begin
  r0 = @Try 4
  r1 = iftrue(r0 % 4 == 0, r0 + 1)
  r2 = @Try r1
  r3 = Option(r2)
  Option(r3)
end
@test r2_1_flatmap == Identity(5)

program3 = @syntax_eff_noautorun begin
  r0 = [1,4]
  [r0, r0, r0]
end
r3 = runhandlers(Vector, program3)
@test r3 == [1,1,1,4,4,4]
@test autorun(program3) == [1,1,1,4,4,4]

iterables = @syntax_eff begin
  r0 = Iterable([1,4])
  Iterable([r0, r0, r0])
end
@test collect(iterables) == [1,1,1,4,4,4]

program4 = @syntax_eff_noautorun begin
  a = [1,2,3]
  b = iftrue(a % 2 == 0) do
    42
  end
  [b, a+b]
end

r4_1 = runhandlers((Identity, Nothing, Vector), program4)
r4_2 = runhandlers((Vector, Nothing, Identity), program4)

@test r4_2 == program4 |>
  eff -> ExtensibleEffects.runhandler(Identity, eff) |>
  eff -> ExtensibleEffects.runhandler(Nothing, eff) |>
  eff -> ExtensibleEffects.runhandler(Vector, eff) |>
  ExtensibleEffects.runlast

@test r4_1 == nothing
@test r4_2 == [nothing, 42, 44, nothing]
@test autorun(program4) == [nothing, 42, 44, nothing]


# test syntax
wrapper(i::Int) = collect(1:i)
wrapper(any) = any

r5_1 = @runhandlers (Vector, Identity, Nothing) @syntax_eff_noautorun wrapper begin
  a = 3
  b = iftrue(a % 2 == 0) do
    42
  end
  [b, a+b]
end
@test r5_1 == [nothing, 42, 44, nothing]

r5_2 = @syntax_eff_noautorun wrapper begin
  a = 3
  b = iftrue(a % 2 == 0) do
    42
  end
  [b, a+b]
end
@test runhandlers((Vector, Identity, Nothing), r5_2) ==  [nothing, 42, 44, nothing]

r5_3 = @runhandlers (Vector, Identity, Nothing) @syntax_eff_noautorun begin
  a = Identity(4)
  b = iftrue(a % 2 == 0) do
    42
  end
  [b, a+b]
end
@test r5_3 == [42, 46]


r5_4 = @runhandlers (Identity, Nothing, Vector) @syntax_eff_noautorun begin
  a = [1,2,3]
  b = iftrue(a % 2 == 0) do
    42
  end
  [b, a+b]
end
@test r5_4 == nothing

handlers = (Const, Identity, Nothing)
r6_1 = @runhandlers handlers @syntax_eff_noautorun begin
  r0 = @Try 4
  r1 = iftrue(r0 % 4 == 0, r0 + 1)
  r2 = @Try r1
  r3 = Option(r2)
  Option(r3)
end
@test r6_1 == 5

r6_2 = @runhandlers (Identity, Const, Nothing) @syntax_eff_noautorun begin
  r0 = @Try 4
  r1 = iftrue(r0 % 4 == 0, r0 + 1)
  r2 = @Try r1
  r3 = Option(r2)
  Option(r3)
end
@test r6_2 == 5



load(a, prefix="") = @ContextManager function (cont)
  println("$(prefix)before $a")
  result = cont(a)
  println("$(prefix)after $a")
  result
end


load_safe(a, prefix="") = @ContextManager function (cont)
  value = [a, a+1]
  println("$(prefix)before $(value)")
  result = cont(value)
  println("$(prefix)after $(value)")
  empty!(value)
  result
end


test_safe() = @runcontextmanager_ @syntax_eff begin
  a = [10,30]
  b = load_safe(a, "1: ")
  c = collect(1:length(b))
  d = load_safe(a + c, "2: ")
  @pure a, b, c, d, length(d)
end

@test @suppress_out test_safe() == [
  (10, Int64[], 1, Int64[], 2),
  (10, Int64[], 2, Int64[], 2),
  (30, Int64[], 1, Int64[], 2),
  (30, Int64[], 2, Int64[], 2),
]
@test splitln(@capture_out test_safe()) == [
  "1: before [10, 11]",
  "2: before [11, 12]",
  "2: after [11, 12]",
  "2: before [12, 13]",
  "2: after [12, 13]",
  "1: after [10, 11]",
  "1: before [30, 31]",
  "2: before [31, 32]",
  "2: after [31, 32]",
  "2: before [32, 33]",
  "2: after [32, 33]",
  "1: after [30, 31]",
]

a = Eff(Vector)
b = Eff(Vector)
@pure flatten(a, b)

function ap(f::Eff, a::Eff)
  Eff(NoEffect())
end
Eff((Vector), Continuation(..., a -> begin
  Eff((Vector), Continuation(..., b -> begin
    noeffect(flatten(a, b))
  end))
end))


load_test1() = @runcontextmanager_ @runhandlers (Vector, Identity, Nothing) @syntax_eff_noautorun begin
  a = [1, 4, 7]
  b = load(a+1, "first ")
  @pure "hi there"
  c = iftrue(b % 2 == 0) do
    a + b
  end
  d = load(c+1, "second ")
  @pure a, b, c, d
end



@test @suppress_out load_test1() == [(1,2,3,4), nothing, (7, 8, 15, 16)]
@test splitln(@capture_out load_test1()) == [
  "first before 2"
  "second before 4"
  "second after 4"
  "first after 2"
  "first before 5"
  "first after 5"
  "first before 8"
  "second before 16"
  "second after 16"
  "first after 8"
]

load_test2() = @runcontextmanager_ @syntax_eff begin
  a = [1, 4, 7]
  b = load(a+1, "first ")
  @pure "hi there"
  c = iftrue(b % 2 == 0) do
    a + b
  end
  d = load(c+1, "second ")
  @pure a, b, c, d
end

@test @suppress_out load_test2() == [(1,2,3,4), nothing, (7, 8, 15, 16)]
@test splitln(@capture_out load_test2()) == [
  "before 2"
  "before 4"
  "after 4"
  "after 2"
  "before 5"
  "after 5"
  "before 8"
  "before 16"
  "after 16"
  "after 8"
]

@syntax_flatmap begin
  a = [1, 4, 7]
  b = load(a+1, "first ")
  @pure "hi there"
  c = iftrue(b % 2 == 0) do
    a + b
  end
  d = load(c+1, "second ")
  @pure a, b, c, d
end


# Just to compare, the same can be run through syntax_flatmap
flatmap_style() = @syntax_flatmap begin
  a = [1, 4, 7]
  b = load(a+1)
  @pure "hi there"
  c = iftrue(b % 2 == 0) do
    a + b
  end
  d = load(c+1)
  @pure a, b, c, d
end
@test @suppress_out flatmap_style() == [(1,2,3,4), nothing, (7,8,15,16)]
@test splitln(@capture_out flatmap_style()) == [
  "before 2"
  "before 4"
  "after 4"
  "after 2"
  "before 5"
  "after 5"
  "before 8"
  "before 16"
  "after 16"
  "after 8"
]


# Task / Future
# -------------

efftask = @async @syntax_eff begin
  a = @async 3
  b = @async begin sleep(1); 5 end
  @pure a, b
end
@test fetch(efftask) == (3,5)

using Distributed
efffuture = @spawnat :any @syntax_eff begin
  a = @spawnat :any 3
  b = @spawnat :any begin sleep(1); 5 end
  @pure a, b
end
@test fetch(efffuture) == (3,5)


# Writer
# ------

effwriter = @syntax_eff begin
  a = Writer("hello ", 3)
  b = Writer("world!", 5)
  @pure a, b
end
@test effwriter.acc == "hello world!"
@test effwriter.value == (3, 5)

effwriter2 = @syntax_eff begin
  a = Writer("hello ", 3)
  b = collect(a:a+2)
  c = Writer("world!", b*b)
  @pure a, b, c
end

@test effwriter2.acc == "hello world!world!world!"
@test effwriter2.value == [(3, 3, 9), (3, 4, 16), (3, 5, 25)]

effwriter3 = @runhandlers (WriterHandler("PURE"), Vector) @syntax_eff_noautorun begin
  a = Writer("hello ", 3)
  b = collect(a:a+2)
  c = Writer("world!", b*b)
  @pure a, b, c
end
@test effwriter3.acc == "hello world!world!world!PURE"
@test effwriter3.value == [(3, 3, 9), (3, 4, 16), (3, 5, 25)]


# Callable
# --------

# callable is the only standard type which needs a custom handler
# hence a perfect example of how such custom handlers are lovely integrated into the API

myflatmap = @syntax_flatmap begin
  a = Callable(x -> x+2)
  b = Callable(x -> a + x)
  @pure a, b
end
@test myflatmap(3) == (5, 8)

myeff = Callable(function(args...; kwargs...)
  @runhandlers CallableHandler(args...; kwargs...) @syntax_eff begin
    a = Callable(x -> x+2)
    b = Callable(x -> a + x)
    @pure a, b
  end
end)
@test myeff(3) == (5, 8)

# we provide a custom macro for this common callable pattern which does exactly the same

myeff2 = @runcallable @syntax_eff begin
  a = Callable(x -> x+2)
  b = Callable(x -> a + x)
  @pure a, b
end
@test myeff2(3) == (5, 8)

myeff3 = @runcallable @syntax_eff begin
  v = [1,3,4]
  a = Callable(x -> x+v)
  o = isodd(a) ? Option(100) : Option()
  b = Callable(x -> x + a + o)
  @pure v, a, o, b
end

@test myeff3(1) == [nothing, nothing, (4,5,100,106)]
@test myeff3(2) == [(1,3,100,105), (3,5,100,107), nothing]


# Really nice to have: We create optimal code!!!
@code_native myeff3(1)
comparef(x) = [isodd(v+x) ? (v, v+x, 100, v+x+100) : nothing for v in [1,3,4]]
@code_native comparef(1)  # suprisingly, this is even a bit larger in machine code


# State
# -----

state_flatmap = @syntax_flatmap begin
  a = State(x -> (x+2, x*x))
  b = State(x -> (a + x, x))
  @pure a, b
end
@test state_flatmap(3) == ((5,14), 9)

state_eff = @runstate @syntax_eff begin
  a = State(x -> (x+2, x*x))
  b = State(x -> (a + x, x))
  @pure a, b
end
@test state_eff(3) == ((5,14), 9)

# nesting Callable and State works well, because Callable uses `@insert_into_runhandlers` to add its handler.
callable_state_eff = @runcallable @runstate @syntax_eff begin
  v = [1,3,4]
  a = State(s -> (v+s, s*s))
  o = isodd(a) ? Option(100) : Option()
  b = Callable(x -> x + a + o)
  @pure v, a, o, b
end

vector, state = callable_state_eff(1)(3)
@test state == 6561
@test vector == [nothing, nothing, (4, 85, 100, 186)]

# CAUTION: the other way around it does not interact well, actually we implemented to throw an error
@test_throws ErrorException @runstate @runcallable @syntax_eff begin
  v = [1,3,4]
  a = State(s -> (v+s, s*s))
  o = isodd(a) ? Option(100) : Option()
  b = Callable(x -> x + a + o)
  @pure v, a, o, b
end

# We could have allowed for this interaction as well, using `@insert_into_runhandlers`, however this would lead
# to non-well-formed results:
# The outer level should be a State then, however it is not, it just has a plain Callable inside, without added state,
# while the state is actually added WITHIN the callable.


# TODO Iterable







# compared to syntax_flatmap, syntax_eff can correctly handle alternating Vector and Single-Element-Containers
# ------------------------------------------

# ContextManager as main Monad

load_square(x, prefix="") = @ContextManager function (cont)
  println("$(prefix)before $x")
  result = cont(x*x)
  println("$(prefix)after $x")
  result
end

cm_vector() = @syntax_eff begin
  i = load_square(4)
  v = [i, i+1, i+3]
  @pure v + 2
end
@test @suppress(cm_vector()) == [4*4+0+2, 4*4+1+2, 4*4+3+2]
@test_throws MethodError splitln(@capture_out cm2(x -> x)) == ["before 4", "after 4"]


# ContextManager as sub monad

vector2() = @syntax_eff begin
  i = [1,2,3]
  c = load_square(i)
  @pure c + 2
end
@test @suppress(vector2()) == [1*1+2, 2*2+2, 3*3+2]
@test splitln(@capture_out vector2()) == [
  "before 1", "after 1", "before 2", "after 2", "before 3", "after 3"]


# alternating contextmanager and vector does not work, as there is no way to convert a vector to a contextmanager

multiplecm() = @syntax_eff begin
  i = [1,2,3]
  c = load(i, "i ")
  j = [c, c*c]
  c2 = load(j, "j ")
  @pure c + c2
end

@test @suppress(multiplecm()) == [2, 2, 4, 6, 6, 12]
@test splitln(@capture_out multiplecm()) == ["i before 1",
  "j before 1",
  "j after 1",
  "j before 1",
  "j after 1",
  "i after 1",
  "i before 2",
  "j before 2",
  "j after 2",
  "j before 4",
  "j after 4",
  "i after 2",
  "i before 3",
  "j before 3",
  "j after 3",
  "j before 9",
  "j after 9",
  "i after 3"]
