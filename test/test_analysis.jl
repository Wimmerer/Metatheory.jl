using MatchCore

# example assuming * operation is always binary

# ENV["JULIA_DEBUG"] = Metatheory

struct NumberFold <: AbstractAnalysis
    egraph::EGraph
    data::Dict{Int64, Any}
end

# Mandatory for AbstractAnalysis
NumberFold(g::EGraph) = NumberFold(g, Dict{Int64, Any}())

# This should be auto-generated by a macro
function EGraphs.make(an::NumberFold, n)
    n isa Number && return n

    if n isa Expr && Meta.isexpr(n, :call)
        if n.args[1] == :*
            l = n.args[2]
            r = n.args[3]

            if get(an, l, nothing) isa Number && get(an, r, nothing) isa Number
                return an[l] * an[r]
            end
        elseif n.args[1] == :+
            l = n.args[2]
            r = n.args[3]

            if get(an, l, nothing) isa Number && get(an, r, nothing) isa Number
                return an[l] + an[r]
            end
        end
    end
    return nothing
end

function EGraphs.join(analysis::NumberFold, from, to)
    if from isa Number
        if to isa Number
            @assert from == to
        else return from
        end
    end
    return to
end

function EGraphs.modify!(an::NumberFold, id::Int64)
    g = an.egraph
    if an[id] isa Number
        newclass = EGraphs.add!(g, an[id])
        merge!(g, newclass.id, id)
    end
end

Base.setindex!(an::NumberFold, value, id::Int64) = setindex!(an.data, value, id)
Base.getindex(an::NumberFold, id::Int64) = an.data[id]
Base.haskey(an::NumberFold, id::Int64) = haskey(an.data, id)
Base.delete!(an::NumberFold, id::Int64) = delete!(an.data, id)

comm_monoid = @theory begin
    a * b => b * a
    a * 1 => a
    a * (b * c) => (a * b) * c
end

G = EGraph(:(3 * 4))
addanalysis!(G, NumberFold)
@testset "Basic Constant Folding Example - Commutative Monoid" begin
    # addanalysis!(G, NumberFold())
    @test (true == @areequalg G comm_monoid 3 * 4 12)

    @test (true == @areequalg G comm_monoid 3 * 4 12 4*3  6*2)
end


@testset "Basic Constant Folding Example 2 - Commutative Monoid" begin
    ex = :(a * 3 * b * 4)
    G = EGraph(cleanast(ex))
    addanalysis!(G, NumberFold)
    display(G.M); println()
    display(G.analyses[1].data); println()
    @test (true == @areequalg G comm_monoid (3 * a) * (4 * b) (12*a)*b ((6*2)*b)*a)
end

@testset "Basic Constant Folding Example - Adding analysis after saturation" begin
    G = EGraph(:(3 * 4))
    # addexpr!(G, 12)
    saturate!(G, comm_monoid)
    addexpr!(G, :(a * 2))
    addanalysis!(G, NumberFold)
    saturate!(G, comm_monoid)

    # display(G.M); println()
    # println(G.root)
    # display(G.analyses[an]); println()

    @test (true == areequal(G, comm_monoid, :(3 * 4), 12, :(4*3), :(6*2)))

    ex = :(a * 3 * b * 4)
    G = EGraph(cleanast(ex))
    addanalysis!(G, NumberFold)
    @test (true == areequal(G, comm_monoid, :((3 * a) * (4 * b)), :((12*a)*b),
        :(((6*2)*b)*a)))
end
