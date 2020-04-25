#=
# Description of the algorithm and definition of used symbols

## 0. Input embedding
s is the input timeseries or Dataset.
On s one performs a d-dimensional embedding, that uses a combination of d timeseries
(with arbitrary amount of repetitions) and d delay times.

I.e. input is `s, τs, js`, with `js, τs` being tuples.

## 1. Core loop given a specific input embedding
We have a d-dimensional embedding, whose each entry is an arbitrary choice out of
the available timeseries (if we have multiple input timeseries, otherwise they are all the
same) and each entry is also defined with respect to an arbitrary delay.

Define a radius δ around point v in ℝᵈ space (d-dimensional embedding). k points are inside
the δ-ball (with respect to some metric) around v. For simplicity, the time index of
v is t0. The other poinds inside the δ_ball have indices i (with several i).

We want to check if we can add an additional dimension to the embedding, using the j-th
timeseries. We check with continuity statistic of Pecora et al.

let x(t+τ) ≡ s_j(t+τ) be this extra dimension we add into the embedding. Out of the
k points in the δ-ball, we count l of them that land into a range ε around x.  Notice that
"points" is a confusing term that should not be used interchange-bly. Here in truth we
refer to **indices** not points. Because of delay embedding, all points are mapped 1-to-1
to a unique time idex. We count the x points with the same time indices ti, if they
are around the original x point with index t0.

Now, if l ≥ δ_to_ε_amount[k] (where δ_to_ε_amount a dictionary defined below), we can
reject the null hypothesis (that the point mapping was by chance), and thus we satisfy
the continuity criterion.

## 2. Finding minimum ε

Notice that in the current code implementation, δ (which is a real number)
is never given/existing in code.
Let a fiducial point v, and we find the k nearest neighbors (say Vs)
and then map their indices to the ε-space. The map of the fiducial point in ε-space
is a and the map of the neighbors is As.

In the ε-space we calculate the distances of As from a. We then sort these distances.

We want the minimum range ε★ within which there are at least l (l = δ_to_ε_amount[k])
neighbors of a. This is simply the l-th maximum distance of As from a.
Why? because if ε★ was any smaller, one neighbor wouldn't be a neighbor anymore and
we would have 1 less l.

## 3. Averaging ε
We repeat step 1 and 2 for several different input points v, and possibly several
input `k`, and average the result in ⟨ε★⟩.

The larger ⟨ε★⟩, the more functionaly independent is the new d+1 entry to the rest
d entries of the embedding.

## Creating a proper embedding
The Pecora embedding is a sequential process. This means that one should start with
a 1-dimensional embedding, with delay time 0 (i.e. a single timeseries).
Then, one performs steps 1-3 for a
choice of one more embedded dimension, i.e. the j-th timeseries and a delay τ.
The optimal choice for the second dimension of the embedding is the j entry with highest
⟨ε★⟩ and τ in a local maximum of ⟨ε★⟩.

Then these two dimensions are used again as input to the algorithm, and sequentially
the third optimal entry for the embedding is chosen. Each added entry successfully
reduces ⟨ε★⟩ for the next entry.

This process continues until ε cannot be reduced further, in which scenario the
process terminates and we have found an optimal embedding that maximizes
functional independence among the dimensions of the embedding.

## The undersampling statistic
Because real world data are finite, the aforementioned process (of seeing when ⟨ε★⟩
will saturate) isn't very accurate because as the dimension of v increases, and
as τ increases, we are undersampling a high-dimensional object.

To counter this, one calcualtes the undersampling statistic ⟨Γ⟩ like so:
For each timeseries calculate the (normalized) histogram, i.e. pdf function
ρ, by using e.g. `db` bins.
Then, for each timeseries x prepare the function σ(ζ), defined as
σ(ζ) = ∫ρ(x) ρ(ζ-x) dx
where ζ is positive, running from 0 to max(x)-min(x).

The following part of the algorithm demands using Chebyshev metric for nearest
neighbors (see performance notes for why)!
Let v be a fiducial point. Create a point q = (v..., a), i.e. the fiducial point
in the product of the δ- and ε- spaces. Now, let qNN be the nearest neigbhor of q.
For every entry of q, calculate ξᵢ=|qᵢ - qNNᵢ|. Then, calculate the integral
Γᵢ = ∫_0 ^(ξᵢ) σ_{J[i]}(ζ) dζ
Then Γ is the maximum of Γᵢ . The undersampling statistic ⟨Γ⟩ is the average of
Γ over all fiducial points.

If Γ>β we are undersampling and thus we don't have statistical confidence
to continue computing ε★.

## Perforamance notes
An optimized σ function is necessary. As many σ functions as timeseries existing
both in the embedding as well as in J are neccessary, irrespectively of the size
of `js`, the input embedding (because the same σ is reused if the same timeseries is
delayed). The optimized calculation of σ is done by assuming that ξ is always at a
bin edge. Thus, the higher `db` the more accurate the computation.

Now, finding the neighbor qNN is extremely tricky. If we were to do it in Euclidean
norm, then for every τ and for every timeseries x we would have to create a _new_
tree and find the nearest neigghbors for all fiducial points. This is insane.

Instead, we use Chebyshev (maximum) norm to simplify the problem. The Chebyshev
distance is the greatest distance along each dimension. Thus, the nearest neighbor
of a fiducial point v0 with index n0 will be the one whose Chebyshev distance
with v0 is the smallest. Let this distance be d0 and this index ni.

We now look at the "ε space", where the x timeseries lives.
We calculate d = |x(ni+τ) - x(n0+τ)|. If d ≤ d0, nothing changes,
and q_ni is the nearest neighbor of q_n0 (just as v_ni is the nearest neighbor to v_n0).
This happens because any other point with index nj would have a Chebyshev distance from
q_n0 that is greater than the existing d0 (since we know guaranteed that the existing
dimensions in v space have _more_ difference along each dimension, since the Chebyshev
is the maximum of those).

Now, if d is greater than d0, then we have to actually find the nearest neighbor,
since there is no guarantee that q_ni is still the nearest neighbor of q_n0.
The extra dimension has _increased_ the Chebyshev distance between them, and we
don't know whether there exists some new point q_nj whose Chebyshev distance from q_n0
is between d0 < dj ≤ d. Here is how we find the nearest neighbor:

1. We collect all indices i that satisfy d0 < |x(ni+τ) - x(n0+τ)| ≤ d, and sort them
   by their distance
2. We start iterating over these indices i, checking the Chebyshev distance of the
   points in v space with index i, with respect to the point with index n0
3. If we find distance that is less than `d`, we terminate the algorithm, and that
   i is the true nearest neighbor in q-space.
4. If not, and we have exhausted all i, then indeed the original ni
   remains the true neighbor.

=#

using Distances, Statistics, StatsBase, Neighborhood
export pecora

# TODO: Generalize the table for more α values

"""
Table 1 of Pecora (2007), i.e. the necessary amount of points for given δ points
that *must* be mapped into the ε set to reject the null hypothesis for p=0.5
and α=0.05.
"""
const δ_to_ε_amount = Dict(
    5=>5,
    6=>6,
    7=>7,
    8=>7,
    9=>8,
    10=>9,
    11=>9,
    12=>9,
    13=>10,
)

"""
    pecora(s, τs, js; kwargs...) → ⟨ε★⟩, ⟨Γ⟩
Compute the (average) continuity statistic `⟨ε★⟩` and undersampling statistic `⟨Γ⟩`
according to Pecora et al.[^Pecoral2007] (A unified approach to attractor reconstruction),
for a given input
`s` (timeseries or `Dataset`) and input generalized embedding defined by `(τs, js)`,
according to [`genembed`](@ref). The continuity statistic represents functional independence
between the components of the existing embedding and one additional timeseries.
The returned results are *matrices* with size `T`x`J`.

## Keyword arguments
* `T = maximum(τs) .+ 1:50`: calculate for all delay times in `T`.
* `J = 1:dimension(s)`: calculate for all timeseries indices in `J`.
  If input `s` is a timeseries, this is always just 1.
* `N = 100`: over how many fiducial points v to average ε★ to produce `⟨ε★⟩, ⟨Γ⟩`
* `K = 7`: the amount of nearest neighbors in the δ-ball (read algorithm description).
  If given a vector, minimum result over all `k ∈ K` is returned.
* `metric = Chebyshev()`: metric with which to find nearest neigbhors in the input
  embedding (ℝᵈ space, `d = length(τs)`).
* `w = 1`: Theiler window (neighbors in time with index `w` close to the point, that
  are excluded from being true neighbors). `w=0` means to exclude only the
  point itself, and no temporal neighbors.
* `undersampling = false` : whether to calculate the undersampling statistic or not
  (if not, zeros are returned for `⟨Γ⟩`). Calculating `⟨Γ⟩` is thousands of times
  slower than `⟨ε★⟩`.
* `db::Int = 100`: Amount of bins used into calculating the histograms of
  each timeseries (for the undersampling statistic).

## Description
Notice that the full algorithm is too large to discuss here, and is
written in detail (several pages!) in the source code of `pecora`.

[^Pecora2007]: Pecora, L. M., Moniz, L., Nichols, J., & Carroll, T. L. (2007). [A unified approach to attractor reconstruction. Chaos 17(1)](https://doi.org/10.1063/1.2430294).
"""
function pecora(
        s, τs::NTuple{D, Int}, js::NTuple{D, Int} = Tuple(ones(Int, D));
        T = maximum(τs) .+ 1:50, J=maxdimspan(s), N = 100, K = 13, w::Int = 1,
        db = 250, undersampling = false, metric = Chebyshev()
        ) where {D}


    if undersampling
        error("Undersampling statistic is not yet accurate for production use.")
    end
    undersampling && metric ≠ Chebyshev() && error("Chebyshev metric required for undersampling")
    vspace = genembed(s, τs, js)
    vtree = searchstructure(KDTree, vspace.data, metric)
    all_ε★ = zeros(length(T), length(J))
    all_Γ = copy(all_ε★)
    allts = columns(s)
    # indices of random fiducial points (with valid time range w.r.t. T)
    L = length(vspace)
    ns = rand(max(1, (-minimum(T) + 1)):min(L, L - maximum(T)), N)
    vs = vspace[ns]
    allNNidxs, allNNdist = all_neighbors(vtree, vs, ns, K, w)
    # prepare things for undersampling statistic
    if undersampling
        # TODO: Allow `db` to be vector
        ρs = histograms(s, unique([js..., J...]), db)
        uidxs = [n[1] for n in allNNidxs]
        udist = [d[1] for d in allNNdist]
    end
    # Loop over potential timeseries to use in new embedding
    for i in 1:length(J)
        x = allts[J[i]]
        x = (x .- mean(x)) ./ std(x) # so that different timeseries can be compared
        all_ε★[:, i] .= continuity_per_timeseries(x, ns, allNNidxs, T, K)
        if undersampling
            println("Started undersampling for $(J[i]) timeseries")
            all_Γ[:, i] .= undersampling_per_timeseries(
                x, vspace, ns, uidxs, udist, [js..., J[i]], T, ρs
            )
        end
    end
    return all_ε★, all_Γ
end

"""
    all_neighbors(vtree, vs, ns, K, w)
Return the `maximum(K)`-th nearest neighbors for all input points `vs`, with indices `ns` in
original data, while respecting the theiler window `w`.
"""
function all_neighbors(vtree, vs, ns, K, w)
    theiler = Theiler(w, ns)
    idxs, dists = bulksearch(vtree, vs, NeighborNumber(maximum(K)), theiler)
    return idxs, dists
end

maxdimspan(s) = 1:size(s)[2]
maxdimspan(s::AbstractVector) = 1
columns(s::AbstractVector) = (s, )

function continuity_per_timeseries(x::AbstractVector, ns, allNNidxs, T, K)
    avrg_ε★ = zeros(size(T))
    for (ι, τ) in enumerate(T) # Loop over the different delays
        c = 0
        for (i, n) in enumerate(ns) # Loop over fiducial points
            NNidxs = allNNidxs[i] # indices of k nearest neighbors to v
            # Check if any of the indices of the neighbors falls out of temporal range
            any(j -> (j+τ > length(x)) | (j+τ < 1), NNidxs) && continue
            # If not, calculate minimum ε
            avrg_ε★[ι] += ε★(x, n, τ, NNidxs, K)
            c += 1
        end
        c == 0 && error("Encountered astronomically small chance of all neighbors having "*
                        "invalid temporal range... Run the function again or decrease `w`.")
        avrg_ε★[ι] /= c
    end
    return avrg_ε★
end

function ε★(x, n, τ, NNidxs, K::AbstractVector)
    a = x[n+τ] # fiducial point in ε-space
    @inbounds dis = [abs(a - x[i+τ]) for i in NNidxs]
    ε = zeros(length(K))
    for (i, k) in enumerate(K)
        sortedds = sort!(dis[1:k]; alg = QuickSort)
        l = δ_to_ε_amount[k]
        ε[i] = sortedds[l]
    end
    return minimum(ε)
end

function ε★(x, n, τ, NNidxs, K::Int)
    a = x[n+τ] # fiducial point in ε-space
    @inbounds dis = [abs(a - x[i+τ]) for i in NNidxs]
    sortedds = sort!(dis; alg = QuickSort)
    l = δ_to_ε_amount[K]
    ε = sortedds[l]
end

##########################################################################################
# Undersampling statistic code
##########################################################################################
function undersampling_per_timeseries(x, vspace, ns, uidxs, udist, JS, T, ρs)
    avrg_Γ = zeros(size(T))
    for (ι, τ) in enumerate(T) # loop over delay times
        println("τ = $τ")
        c = 0
        τr = max(1, (-τ + 1)):min(length(vspace), length(vspace) - τ) # valid time range
        for (i, n0) in enumerate(ns) # Loop over fiducial points
            ni, d0 = uidxs[i], udist[i] # distances in vspace
            # Check if the neighbor + τ falls out of temporal range
            (ni+τ > length(x)) | (ni+τ < 1) && continue
            nℓ = true_neighbor_index(ni, n0, vspace, d0, x, τ, τr)
            q = (vspace[n0]..., x[n0+τ])
            qNN = (vspace[nℓ]..., x[nℓ+τ])
            avrg_Γ[ι] += Γ(q, qNN, JS, ρs)
            c += 1
        end
        avrg_Γ[ι] /= c
    end
    return avrg_Γ
end

function Γ(q, qNN, JS, ρs)
    Γmax = 0.0
    for i in 1:length(q)
        ξᵢ = abs(q[i] - qNN[i])
        ρᵢ = ρs[JS[i]]
        Γᵢ = integral_σ(ρᵢ, ξᵢ)
        Γmax = Γᵢ > Γmax ? Γᵢ : Γmax
    end
    return Γmax
end

# this function assumes Chebyshev norm
function true_neighbor_index(ni, n0, vspace, d0, x, τ, τr)
    d = abs(x[ni+τ] - x[n0+τ])
    if d ≤ d0
        return ni
    else # we now have to find a different point
        # TODO: This can be optimized with a dedicated function
        # that doesn't allocate 4 extra arrays...
        tocheck = τr[findall(i -> d0 < abs(x[i+τ] - x[n0+τ]) ≤ d, τr)]
        dist = map(i -> abs(x[i+τ] - x[n0+τ]), tocheck)
        _si = sortperm(dist)
        tocheck = tocheck[_si]
        dist = dist[_si]
        true_ni = ni
        for i in tocheck
            dj = evaluate(Chebyshev(), vspace[n0], vspace[i])
            if dj < d
                true_ni = i
                break
            end
        end
        return true_ni
    end
end

function histograms(s, J, db)
    sort!(J); hs = []
    for j in J
        x = s[:, j]
        h = normalize(fit(Histogram, x; nbins = db); mode = :pdf)
        push!(hs, h)
    end
    H = typeof(hs[1])
    return Dict{Int, H}((J[i]=>hs[i]) for i in 1:length(J))
end

"calculate σ(ζ) = ∫ρ(x) ρ(ζ-x) dx , approximating ζ to be in bin start (whole bin counts)."
function difference_distribution(ρ::Histogram, ζ)
    e = ρ.edges[1]
    dx = Float64(e.step)
    ∫ = 0.0
    vmin = max(1, searchsortedfirst(e, ζ-maximum(e)))
    vmax = min(length(e)-1, searchsortedfirst(e, ζ-minimum(e)))
    valid = vmin:vmax # all indices where (ζ-emax, ζ-emin) ∈ e
    # @show e, valid, ζ
    for i in 1:length(valid)
        # x = e[valid[i]]
        # ζmx = e[valid[end]-i+1] # ζ - x
        # @show (valid[i], valid[end]-i, x, ζmx, ζ-x)
        # we know the bin of x and ζ-x
        ∫ += (ρ.weights[valid[i]] * ρ.weights[valid[end]-i+1])*dx
    end
    return ∫ # I don't need trapezoid rule, histogram is PDF normalized
end

"approximately calculate ∫_0 ^(ξ) σ(ζ) dζ."
function integral_σ(ρ, ξ)
    e = ρ.edges[1]
    dζ = Float64(e.step)
    ∫ = 0.0
    for ζ in 0.0:dζ:ξ
        σ = difference_distribution(ρ, ζ)
        ∫ += σ*dζ
    end
    return ∫
end
