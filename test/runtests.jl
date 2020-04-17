using Test
using ExtensibleEffects
using DataTypesBasic
DataTypesBasic.@overwrite_Some
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
r2_1 = runhandlers((Option, Try), program2)
@test r2_1 == Option(Try(5))
r2_2 = runhandlers((Try, Option), program2)
@test r2_2 == Try(Option(5))
@test autorun(program2) === Try(Option(5))

program3 = @syntax_eff_noautorun begin
  r0 = [1,4]
  [r0, r0, r0]
end
r3 = runhandlers(Vector, program3)
@test r3 == [1,1,1,4,4,4]
@test autorun(program3) == [1,1,1,4,4,4]

program4 = @syntax_eff_noautorun begin
  a = [1,2,3]
  b = iftrue(a % 2 == 0) do
    42
  end
  [b, a+b]
end

r4_1 = runhandlers((Option, Vector), program4)
r4_2 = runhandlers((Vector, Option), program4)

ExtensibleEffects.runlast(ExtensibleEffects.runhandler(Vector, ExtensibleEffects.runhandler(Option, program4)))
@test r4_1 isa None
@test flatten(r4_2) == [42, 44]
@test flatten(autorun(program4)) == [42, 44]


# test syntax
wrapper(i::Int) = collect(1:i)
wrapper(any) = any

r5_1 = @runhandlers (Vector, Option) @syntax_eff_noautorun wrapper begin
  a = 3
  b = iftrue(a % 2 == 0) do
    42
  end
  [b, a+b]
end
@test flatten(r5_1) ==  [42, 44]

r5_2 = @syntax_eff_noautorun wrapper begin
  a = 3
  b = iftrue(a % 2 == 0) do
    42
  end
  [b, a+b]
end
@test flatten(runhandlers((Vector, Option), r5_2)) ==  [42, 44]

r5_3 = @runhandlers (Vector, Option) @syntax_eff_noautorun begin
  a = NoEffect(4)
  b = iftrue(a % 2 == 0) do
    42
  end
  [b, a+b]
end
@test flatten(r5_3) ==  [42, 46]


r5_4 = @runhandlers (Option, Vector) @syntax_eff_noautorun begin
  a = [1,2,3]
  b = iftrue(a % 2 == 0) do
    42
  end
  [b, a+b]
end
@test r5_4 isa None

handlers = (Try, Option)
r6_1 = @runhandlers handlers @syntax_eff_noautorun begin
  r0 = @Try 4
  r1 = iftrue(r0 % 4 == 0, r0 + 1)
  r2 = @Try r1
  r3 = Option(r2)
  Option(r3)
end
@test r6_1 == Try(Option(5))

r6_2 = @runhandlers (Option, Try) @syntax_eff_noautorun begin
  r0 = @Try 4
  r1 = iftrue(r0 % 4 == 0, r0 + 1)
  r2 = @Try r1
  r3 = Option(r2)
  Option(r3)
end
@test r6_2 == Option(Try(5))




load(a) = @ContextManager function (cont)
  println("before $a")
  result = cont(a)
  println("after $a")
  result
end

load_test1() = @runhandlers (Vector, ContextManager, Option) @syntax_eff_noautorun begin
  a = [1, 4, 7]
  b = load(a+1)
  @pure "hi there"
  c = iftrue(b % 2 == 0) do
    a + b
  end
  d = load(c+1)
  @pure a, b, c, d
end
@test @suppress_out flatten(load_test1()) == [(1,2,3,4), (7, 8, 15, 16)]
@test splitln(@capture_out load_test1()) == [
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

load_test2() = @syntax_eff begin
  a = [1, 4, 7]
  b = load(a+1)
  @pure "hi there"
  c = iftrue(b % 2 == 0) do
    a + b
  end
  d = load(c+1)
  @pure a, b, c, d
end

@test @suppress_out flatten(load_test2()) == [(1,2,3,4), (7, 8, 15, 16)]
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


# Just to compare, the same can be run through syntax_flatmap, where the result is the very same, however
# the implementaion is way more complicated as the interaction between ContextManager and everything else had to be
# defined.
# To compare, the implementation of ContextManager for ExtensibleEffects is only 2 lines long.

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
@test @suppress_out flatmap_style() == [(1,2,3,4), (7,8,15,16)]
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
  @runhandlers CallWith(args...; kwargs...) @syntax_eff begin
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

@test flatten(myeff3(1)) == [(4,5,100,106)]
@test flatten(myeff3(2)) == [(1,3,100,105), (3,5,100,107)]


# Really nice to have: We create optimal code!!!
@code_native flatten(myeff3(1))
comparef(x) = [(v, v+x, 100, v+x+100) for v in [1,3,4] if isodd(v+x)]
@code_native comparef(1)  # surprisingly, this is even a bit larger in machine code


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
