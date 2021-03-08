using Test
using Exmonicon
using Exmonicon.Types
using Exmonicon.Analysis
using Exmonicon.CodeGen
using Exmonicon.Transform

@testset "is_kw_fn" begin
    @test is_kw_fn(:(
        function foo(x::Int; kw=1)
        end
    ))

    ex = :(function (x::Int; kw=1) end)
    @test is_kw_fn(ex)

    @test !is_kw_fn(:(
        function foo(x::Int)
        end
    ))

    @test !is_kw_fn(:(
        function (x::Int)
        end
    ))
end

@testset "JLFunction(ex)" begin
    ex = :(function foo(x::Int, y::Type{T}) where {T <: Real}
        return x
    end)

    jlfn = JLFunction(ex)
    @test jlfn.head === :function
    @test jlfn.name === :foo
    @test jlfn.args == Any[:(x::Int), :(y::Type{T})]
    @test jlfn.kwargs === nothing
    @test jlfn.whereparams == Any[:(T <: Real)]
    @test jlfn.body == ex.args[2]
    @test codegen_ast(jlfn) == ex

    ex = :(function (x, y)
        return 2
    end)

    jlfn = JLFunction(ex)
    print(jlfn)
    @test jlfn.head === :function
    @test jlfn.args == [:x, :y]
    @test jlfn.name === nothing
    @test jlfn.whereparams === nothing
    @test codegen_ast(jlfn) == ex

    ex = :(function (x, y; kw=2)
        return "aaa"
    end)

    jlfn = JLFunction(ex)
    print(jlfn)
    @test jlfn.head === :function
    @test jlfn.args == Any[:x, :y]
    @test jlfn.kwargs == Any[Expr(:kw, :kw, 2)]
    @test jlfn.name === nothing
    @test codegen_ast(jlfn) == ex

    ex = :((x, y)->sin(x))

    jlfn = JLFunction(ex)
    print(jlfn)
    @test jlfn.head === :(->)
    @test jlfn.args == Any[:x, :y]
    @test jlfn.kwargs === nothing
    @test jlfn.name === nothing
    @test codegen_ast(jlfn) == ex

    # canonicalize head when it's a block
    ex = :(function (x::Int; kw=1) end)
    jlfn = JLFunction(ex)
    print(jlfn)
    @test jlfn.head === :function
    @test jlfn.args == Any[:(x::Int)]
    @test jlfn.kwargs == Any[Expr(:kw, :kw, 1)]
    @test codegen_ast(jlfn) == Expr(:function, Expr(:tuple, Expr(:parameters, Expr(:kw, :kw, 1)), :(x::Int)), jlfn.body)
end

@testset "JLStruct(ex)" begin
    ex = :(struct Foo
        x::Int
    end)

    jlstruct = JLStruct(ex)
    print(jlstruct)
    @test jlstruct.name === :Foo
    @test jlstruct.ismutable === false
    @test length(jlstruct.fields) == 1
    @test jlstruct.fields[1].name === :x
    @test jlstruct.fields[1].type === :Int
    @test jlstruct.fields[1].line isa LineNumberNode
    @test codegen_ast(jlstruct) == ex

    ex = :(mutable struct Foo{T, S <: Real} <: AbstractArray
        a::Float64

        function foo(x, y, z)
            new(1)
        end
    end)

    jlstruct = JLStruct(ex)
    print(jlstruct)
    @test jlstruct.ismutable == true
    @test jlstruct.name === :Foo
    @test jlstruct.typevars == Any[:T, :(S <: Real)]
    @test jlstruct.supertype == :AbstractArray
    @test jlstruct.misc[1] == ex.args[3].args[end]
    @test rm_lineinfo(codegen_ast(jlstruct)) == rm_lineinfo(ex)
end

@testset "JLKwStruct" begin
    ex = :(struct Foo{N, T}
        x::T = 1
    end)

    def = JLKwStruct(ex)
    print(def)

    @test rm_lineinfo(codegen_ast(def)) == rm_lineinfo(quote
        struct Foo{N, T}
            x::T
        end
        function Foo{N}(; x::T = 1) where {N, T}
            Foo{N, T}(x)
        end
    end)
end