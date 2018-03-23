using PyRhodium
using Roots
using Distributions
using DataFrames
using IterableTables
using NamedTuples

function lake_problem(;pollution_limit=nothing,
         b = 0.42,       # decay rate for P in lake (0.42 = irreversible)
         q = 2.0,        # recycling exponent
         mean = 0.02,    # mean of natural inflows
         stdev = 0.001,  # standard deviation of natural inflows
         utility = 0.4,  # utility from pollution
         delta = 0.98,   # future utility discount rate
         nsamples = 100) # monte carlo sampling of natural inflows)

    Pcrit = fzero(x -> x^q/(1+x^q) - b*x, 0.01, 1.5)
    nvars = length(pollution_limit)
    X = zeros(nvars)
    average_daily_P = zeros(nvars)
    reliability = 0.0

    d = LogNormal(log(mean^2 / sqrt(stdev^2 + mean^2)),sqrt(log(1.0 + stdev^2 / mean^2)))
    
    natural_inflows = zeros(nvars)
    
    for i in 1:nsamples
        X[1] = 0.0        
        
        rand!(d, natural_inflows)
        
        for t in 2:nvars
            X[t] = (1-b)*X[t-1] + X[t-1]^q/(1+X[t-1]^q) + pollution_limit[t] + natural_inflows[t]
            average_daily_P[t] += X[t]/nsamples
        end
    
        reliability += sum(X .< Pcrit)/(nsamples*nvars)
    end
      
    max_P = maximum(average_daily_P)
    utility = sum(utility.*pollution_limit.*delta.^collect(1:nvars))
    intertia = sum(diff(pollution_limit) .> -0.02)/(nvars-1)
    
    return max_P, utility, intertia, reliability
end

model = Model(lake_problem)

set_parameters!(model, [:pollution_limit,
                        :b,
                        :q,
                        :mean,
                        :stdev,
                        :delta])

set_responses!(model, [:max_P       => :MINIMIZE,
                       :utility     => :MAXIMIZE,
                       :inertia     => :MAXIMIZE,
                       :reliability => :MAXIMIZE])

set_levers!(model, [RealLever("pollution_limit", 0.0, 0.1, length=100)])

nsamples = 100 # 1000
output = optimize(model, "NSGAII", nsamples)

println("Found $(length(output)) optimal policies!")

# fig = scatter2d(output)

policy = output[5]
policies = find(output, "utility > 0.5")

policy = findmax(output, :reliability)

# println("Max Phosphorus in Lake: ", policy.max_P)
# println("Utility:                ", policy.utility)
# println("Inertia:                ", policy.inertia)
# println("Reliability:            ", policy.reliability)

println("Max Phosphorus in Lake: ", policy["max_P"])
println("Utility:                ", policy["utility"])
println("Inertia:                ", policy["inertia"])
println("Reliability:            ", policy["reliability"])

df = DataFrame(output)
# arr = collect(output)

result = apply(output, "total_pollution = sum(pollution_limit)")
policy = findmin(output, :total_pollution)

#
# Scenario discovery
#
policy = Dict("pollution_limit" => fill(0.02, 100))

result = named_tuple(evaluate(model, policy))

println()
println("Max Phosphorus in Lake: ", result.max_P)
println("Utility:                ", result.utility)
println("Inertia:                ", result.inertia)
println("Reliability:            ", result.reliability)

set_uncertainties!(model, 
    [:b     => Uniform(0.1, 0.45),
     :q     => Uniform(2.0, 4.5),
     :mean  => Uniform(0.01, 0.05),
     :stdev => Uniform(0.001, 0.005),
     :delta => Uniform(0.93, 0.99)])

SOWs = sample_lhs(model, 100) # 1000
results = evaluate(model, [merge(i, policy) for i in SOWs])

classification = apply(results, "'Reliable' if reliability > 0.9 else 'Unreliable'")

uncertainties = [obj[:name] for obj in model.pyo[:uncertainties]]

# p = Prim(results, classification, include=uncertainties, coi="Reliable")

# box = p.find_box()
# fig = box.show_tradeoff()