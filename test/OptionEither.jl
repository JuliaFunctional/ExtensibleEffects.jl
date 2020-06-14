using Test
using ExtensibleEffects
using DataTypesBasic
using TypeClasses
using Suppressor
splitln(str) = split(strip(str), "\n")
import ExtensibleEffects: autorun

# Nothing, Const, Identity
# ------------------------

program_option(a) = @syntax_eff_noautorun begin
  r0 = Identity(a)
  r1 = isodd(r0) ? nothing : Identity(3)
  @pure r0, r1
end
@test runhandlers(Option, program_option(1)) == nothing
@test runhandlers(Option, program_option(2)) == Identity((2, 3))

@test runhandlers((Nothing, Identity), program_option(1)) == nothing
@test runhandlers((Nothing, Identity), program_option(2)) == Identity((2, 3))

@test runhandlers((Identity, Nothing), program_option(1)) == nothing
@test runhandlers((Identity, Nothing), program_option(2)) == Identity((2, 3))


program_either(a) = @syntax_eff_noautorun begin
  r0 = @Try a
  r1 = @Try isodd(r0) ? error("nonono") : 3
  @pure r0, r1
end
@test runhandlers(Either, program_either(1)) isa Const
@test runhandlers(Either, program_either(2)) == Identity((2, 3))

@test runhandlers((Const, Identity), program_either(1)) isa Const
@test runhandlers((Const, Identity), program_either(2)) == Identity((2, 3))

# IMPORTANT: order matters
@test runhandlers((Identity, Const), program_either(1)) isa Const
@test runhandlers((Identity, Const), program_either(2)) == Identity((2, 3))


program_optioneither(a) = @syntax_eff_noautorun begin
  r0 = @Try a
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
r2_1 = runhandlers((Const, Nothing, Identity), program_optioneither(4))
@test r2_1 == Identity(5)
@test autorun(program_optioneither(4)) == Identity(5)
@test runhandlers(OptionEither, program_optioneither(4)) == Identity(5)

@test runhandlers((Const, Nothing, Identity), program_optioneither(3)) == nothing
@test autorun(program_optioneither(3)) == nothing
@test runhandlers(OptionEither, program_optioneither(3)) == nothing

programm_optioneither_flatmap(a) = @syntax_flatmap begin
  r0 = @Try a
  r1 = iftrue(r0 % 4 == 0, r0 + 1)
  r2 = @Try r1
  r3 = Option(r2)
  Option(r3)
end
@test programm_optioneither_flatmap(4) == Identity(5)
@test programm_optioneither_flatmap(3) == nothing


# test other syntax

handlers = (Const, Nothing, Identity)
r6_1 = @runhandlers handlers @syntax_eff_noautorun begin
  r0 = @Try 4
  r1 = iftrue(r0 % 4 == 0, r0 + 1)
  r2 = @Try r1
  r3 = Option(r2)
  Option(r3)
end
@test r6_1 == Identity(5)

r6_2 = @runhandlers (Const, Nothing, Identity) @syntax_eff_noautorun begin
  r0 = @Try 4
  r1 = iftrue(r0 % 4 == 0, r0 + 1)
  r2 = @Try r1
  r3 = Option(r2)
  Option(r3)
end
@test r6_2 == Identity(5)
