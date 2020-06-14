using Test
using ExtensibleEffects
using DataTypesBasic
using TypeClasses
using Suppressor
splitln(str) = split(strip(str), "\n")
import ExtensibleEffects: autorun


@testset "Identity/Nothing/Const" begin
  include("OptionEither.jl")
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
