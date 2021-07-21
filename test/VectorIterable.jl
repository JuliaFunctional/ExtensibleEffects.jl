using Test
using ExtensibleEffects
using DataTypesBasic
using TypeClasses
splitln(str) = split(strip(str), "\n")
import ExtensibleEffects: autorun


# Vector/Iterable
# ---------------

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

r4_1 = runhandlers((Const, Identity, Vector), program4)
r4_2 = runhandlers((Vector, Const, Identity), program4)

@test r4_2 == program4 |>
  eff -> ExtensibleEffects.runhandler(Identity, eff) |>
  eff -> ExtensibleEffects.runhandler(Const, eff) |>
  eff -> ExtensibleEffects.runhandler(Vector, eff) |>
  ExtensibleEffects.runlast

@test r4_1 == Const(nothing)
@test r4_2 == [Const(nothing), Identity(42), Identity(44), Const(nothing)]
@test autorun(program4) == [Const(nothing), Identity(42), Identity(44), Const(nothing)]


# test syntax
wrapper(i::Int) = collect(1:i)
wrapper(any) = any

r5_1 = @runhandlers (Vector, Const, Identity) @syntax_eff_noautorun wrapper begin
  a = 3
  b = iftrue(a % 2 == 0) do
    42
  end
  [b, a+b]
end
@test r5_1 == [Const(nothing), Identity(42), Identity(44), Const(nothing)]

r5_2 = @syntax_eff_noautorun wrapper begin
  a = 3
  b = iftrue(a % 2 == 0) do
    42
  end
  [b, a+b]
end
@test runhandlers((Vector, Const, Identity), r5_2) ==  [Const(nothing), Identity(42), Identity(44), Const(nothing)]

r5_3 = @runhandlers (Vector, Const, Identity) @syntax_eff_noautorun begin
  a = Identity(4)
  b = iftrue(a % 2 == 0) do
    42
  end
  [b, a+b]
end
@test r5_3 == [Identity(42), Identity(46)]


r5_4 = @runhandlers (Const, Identity, Vector) @syntax_eff_noautorun begin
  a = [1,2,3]
  b = iftrue(a % 2 == 0) do
    42
  end
  [b, a+b]
end
@test r5_4 == Const(nothing)
