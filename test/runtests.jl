using DataTypesBasic
DataTypesBasic.@overwrite_Base
using TypeClasses
TypeClasses.@overwrite_Base
using ExtensibleEffects
using Test

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
end
r2_1 = program2 |> runeffect(Try) |> runeffect(Option) |> runlast
@test r2_1 == Option(Try(5))
r2_2 = program2 |> runeffect(Option) |> runeffect(Try) |> runlast
@test r2_2 == Try(Option(5))

program3 = @syntax_eff begin
  r0 = [1,4]
  [r0, r0, r0]
end
r3 = program3 |> runeffect(Vector) |> runlast
@test r3 == [1,1,1,4,4,4]

program4 = @syntax_eff begin
  a = [1,2,3]
  b = iftrue(a % 2 == 0) do
    42
  end
  [b, a+b]
end

r4_1 = program4 |> runeffect(Vector) |> runeffect(Option) |> runlast
r4_2 = program4 |> runeffect(Option) |> runeffect(Vector) |> runlast

@test r4_1 isa None
@test [x.value for x in r4_2 if issomething(x)] == [42, 44]




# test syntax
wrapper(i::Int) = collect(1:i)
wrapper(any) = any

r5 = @syntax_eff_run (Vector, Option) wrapper begin
  a = 3
  b = iftrue(a % 2 == 0) do
    42
  end
  [b, a+b]
end
@test flatten(r5) ==  [42, 44]


r5 = @syntax_eff_run (Vector, Option) begin
  a = NoEffect(4)
  b = iftrue(a % 2 == 0) do
    42
  end
  [b, a+b]
end


r6 = @syntax_eff_run (Option, Vector) begin
  a = [1,2,3]
  b = iftrue(a % 2 == 0) do
    42
  end
  [b, a+b]
end
@test r6 isa None

handlers = (Try, Option)
r7_1 = @syntax_eff_run handlers begin
  r0 = @Try 4
  r1 = iftrue(r0 % 4 == 0, r0 + 1)
  r2 = @Try r1
  r3 = Option(r2)
  Option(r3)
end
@test r7_1 == Try(Option(5))

r7_2 = @syntax_eff_run (Option, Try) begin
  r0 = @Try 4
  r1 = iftrue(r0 % 4 == 0, r0 + 1)
  r2 = @Try r1
  r3 = Option(r2)
  Option(r3)
end
@test r7_2 == Option(Try(5))




load(a) = @ContextManager function (cont)
  println("before $a")
  result = cont(a)
  println("after $a")
  result
end

@syntax_eff_run (Vector, ContextManager, Option) begin
  a = [1, 4, 7]
  b = load(a+1)
  @pure "hi there"
  c = iftrue(b % 2 == 0) do
    a + b
  end
  d = load(c+1)
  @pure a, b, c, d
end

@syntax_eff begin
  a = [1, 4, 7]
  b = load(a+1)
  @pure "hi there"
  c = iftrue(b % 2 == 0) do
    a + b
  end
  @pure a, b, c
end


@syntax_flatmap begin
  a = [1, 4, 7]
  b = load(a+1)
  @pure "hi there"
  c = iftrue(b % 2 == 0) do
    a + b
  end
  @pure a, b, c
end
