using LinearAlgebra

export OrthoMADS

"""
    OrthoMADS()

Return an empty OrthoMADS object.

OrthoMADS implements the poll set generation as described in Audet and Le Digabel 2015
Section 3.4.
"""
struct OrthoMADS <: AbstractPoll end

"""
    GenerateDirections(p::DSProblem{T}, o::OrthoMADS)::Vector{Vector{T}}

Generates columns and forms a basis matrix for direction generation.
"""
(GenerateDirections(p::AbstractProblem, o::OrthoMADS)::Matrix) =
    GenerateDirections(p.N, o)

"""
    GenerateDirections(N::Int64, ::OrthoMADS)::Matrix

Generates columns and forms a basis matrix for direction generation,
using the poll set generation as described in Audet and Le Digabel 2015 Section 3.4.
"""
function GenerateDirections(N::Int64, ::OrthoMADS)::Matrix
    dirs_on_unit_sphere = GenerateDirectionsOnUnitSphere(N)
    H = HouseholderTransform(dirs_on_unit_sphere)
	return hcat(H, -H)
end

"""
    GenerateDirectionsOnUnitSphere(N::Int64)

Return an `N` length normalized direction on the unit sphere.
"""
function GenerateDirectionsOnUnitSphere(N::Int64)
    dir = randn(N)
    return dir ./ norm(dir)
end

"""
    HouseholderTransform(q)

Apply the Householder transformation to the vector `q`.
"""
function HouseholderTransform(q)
    nq = norm(q)
    v = q./nq
    return nq^2 .* (I - 2*v*v')
end
