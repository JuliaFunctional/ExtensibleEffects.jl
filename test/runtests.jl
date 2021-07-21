using Test
using ExtensibleEffects
using DataTypesBasic
using TypeClasses
using Documenter

splitln(str) = split(strip(str), "\n")
import ExtensibleEffects: autorun

@test isempty(detect_ambiguities(ExtensibleEffects))

if  v"1.6" <= VERSION < v"1.7"
  # doctests are super instable, hence we only do it for a specific Julia Version
  doctest(ExtensibleEffects)
end

@testset "Identity/Nothing/Const" begin
  include("OptionTryEither.jl")
end

@testset "Vector/Iterable" begin
  include("VectorIterable.jl")
end

@testset "Task/Future" begin
  include("TaskFuture.jl")
end

@testset "ContextManager" begin
  include("ContextManager.jl")
end

@testset "Writer" begin
  include("Writer.jl")
end

@testset "Callable" begin
  include("Callable.jl")
end

@testset "State" begin
  include("State.jl")
end

@testset "NoEffect" begin
  include("NoEffect.jl")
end
