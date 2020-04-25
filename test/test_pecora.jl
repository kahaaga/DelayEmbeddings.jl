using DelayEmbeddings, PyPlot, DynamicalSystemsBase, DelimitedFiles
using Distances
using Random
UNDERSAMPLING = false

# %% Trajectory case
Random.seed!(15151)
using Statistics
lo = Systems.lorenz()
s = trajectory(lo, 1280; dt = 0.02, Ttr = 10.0)
x, y, z = columns(s)
s = Dataset(x, y, z)

js = (1, 2)
τs = (0, 5)
@time es, Γs = pecora(s, τs, js; T = 1:100, N = 1000)

figure()
subplot(211)
for i in 1:3
    plot(es[:, i], label = "τs = $(τs), js = $(js), J = $(i)")
end
ylabel("⟨ε★⟩")
title("lorenz system, multiple timeseries")
legend()
subplot(212)
for i in 1:3
    plot(Γs[:, i], label = "τs = $(τs), js = $(js), J = $(i)")
end
ylabel("⟨Γ⟩")
xlabel("τ (index units)")
