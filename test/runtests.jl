using DataTypesBasic
DataTypesBasic.@overwrite_Base
using TypeClasses
TypeClasses.@overwrite_Base
using ExtensibleEffects
using Test
using Suppressor
splitln(str) = split(strip(str), "\n")

program2 = @syntax_eff begin
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
end :eff
r2_1 = runhandlers((Option, Try), program2)
@test r2_1 == Option(Try(5))
r2_2 = runhandlers((Try, Option), program2)
@test r2_2 == Try(Option(5))
@test autorun(program2) === Try(Option(5))

program3 = @syntax_eff begin
  r0 = [1,4]
  [r0, r0, r0]
end :eff
r3 = runhandlers(Vector, program3)
@test r3 == [1,1,1,4,4,4]
@test autorun(program3) == [1,1,1,4,4,4]

program4 = @syntax_eff begin
  a = [1,2,3]
  b = iftrue(a % 2 == 0) do
    42
  end
  [b, a+b]
end :eff

r4_1 = runhandlers((Option, Vector), program4)
r4_2 = runhandlers((Vector, Option), program4)

@test r4_1 isa None
@test flatten(r4_2) == [42, 44]
@test flatten(autorun(program4)) == [42, 44]


# test syntax
wrapper(i::Int) = collect(1:i)
wrapper(any) = any

r5_1 = @syntax_eff wrapper begin
  a = 3
  b = iftrue(a % 2 == 0) do
    42
  end
  [b, a+b]
end (Vector, Option)
@test flatten(r5_1) ==  [42, 44]

r5_2 = @syntax_eff wrapper begin
  a = 3
  b = iftrue(a % 2 == 0) do
    42
  end
  [b, a+b]
end :eff
@test flatten(runhandlers((Vector, Option), r5_2)) ==  [42, 44]

r5_3 = @syntax_eff begin
  a = NoEffect(4)
  b = iftrue(a % 2 == 0) do
    42
  end
  [b, a+b]
end (Vector, Option)
@test flatten(r5_3) ==  [42, 46]


r5_4 = @runhandlers (Option, Vector) @syntax_eff begin
  a = [1,2,3]
  b = iftrue(a % 2 == 0) do
    42
  end
  [b, a+b]
end
@test r5_4 isa None

handlers = (Try, Option)
r6_1 = @syntax_eff begin
  r0 = @Try 4
  r1 = iftrue(r0 % 4 == 0, r0 + 1)
  r2 = @Try r1
  r3 = Option(r2)
  Option(r3)
end handlers
@test r6_1 == Try(Option(5))

r6_2 = @syntax_eff begin
  r0 = @Try 4
  r1 = iftrue(r0 % 4 == 0, r0 + 1)
  r2 = @Try r1
  r3 = Option(r2)
  Option(r3)
end (Option, Try)
@test r6_2 == Option(Try(5))




load(a) = @ContextManager function (cont)
  println("before $a")
  result = cont(a)
  println("after $a")
  result
end

load_test1() = @syntax_eff begin
  a = [1, 4, 7]
  b = load(a+1)
  @pure "hi there"
  c = iftrue(b % 2 == 0) do
    a + b
  end
  d = load(c+1)
  @pure a, b, c, d
end (Vector, ContextManager, Option)
@test flatten(load_test1()) == [(1,2,3,4), (7, 8, 15, 16)]
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

@test flatten(load_test2()) == [(1,2,3,4), (7, 8, 15, 16)]
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
#=
flatmap_style = @syntax_flatmap begin
  a = [1, 4, 7]
  b = load(a+1)
  @pure "hi there"
  c = iftrue(b % 2 == 0) do
    a + b
  end
  d = load(c+1)
  @pure a, b, c, d
end
@test flatmap_style == [(1,2,3,4), (7,8,15,16)]
=#
