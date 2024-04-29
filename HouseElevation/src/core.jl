using Base: @kwdef
using Distributions
using StatsBase: mean

"""ModelParams contains all the variables that are constant across simulations"""
@kwdef struct ModelParams
    house::House
    years::Vector{Int}
end

"""A SOW contains all the variables that may vary from one simulation to the next, including parameters for a declining discount rate"""
struct SOW{T<:Real}
    slr::Oddo17SLR # the parameters of sea-level rise
    surge_dist::Distributions.UnivariateDistribution # the distribution of storm surge
    st_dr::T # the housing market discount rate parameters, a tuple of shares (e.g., 2% is 0.02)
    lt_dr::T
end

"""A old_SOW contains all the variables that may vary from one simulation to the next"""
struct old_SOW{T<:Real}
    slr::Oddo17SLR # the parameters of sea-level rise
    surge_dist::Distributions.UnivariateDistribution # the distribution of storm surge
    discount_rate::T # the housing market discount rate parameters, a tuple of shares (e.g., 2% is 0.02)
end

"""
In this model, we only hvae one decision variable: how high to elevate the house.
"""
struct Action{T<:Real}
    Δh_ft::T
end
function Action(Δh::T) where {T<:Unitful.Length}
    Δh_ft = ustrip(u"ft", Δh)
    return Action(Δh_ft)
end
