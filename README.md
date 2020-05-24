# DirectSearch.jl
<!-- Currently isn't a stable release -->
<!--[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://EdwardStables.github.io/DirectSearch.jl/stable)-->
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://EdwardStables.github.io/DirectSearch.jl/dev)
[![Build Status](https://travis-ci.com/EdwardStables/DirectSearch.jl.svg?branch=master)](https://travis-ci.com/EdwardStables/DirectSearch.jl)

*This is a temporary mirror of the [main project repo](https://github.com/ImperialCollegeLondon/DirectSearch.jl), development will move back there in mid-May*

DirectSearch.jl provides a framework for the implementation of direct search algorithms, currently focusing on the Mesh Adaptive Direct Search (MADS) family. These are derivative free, black box algorithms, meaning that no analytical knowledge of the objective function or any constraints are needed. This package provides the core MADS algorithms (LTMADS, OrthoMADS, as well as progressive and extreme barrier constraints), and is designed to allow custom algorithms to be easily added.

## Installation

This package is not yet registered. Install with:
```julia
pkg> add https://github.com/EdwardStables/DirectSearch.jl
```
And import as with any Julia package:
```julia
using DirectSearch
```

## Usage

### Problem Specification
The core data structure is the `DSProblem` type. At a minimum it requires the dimension of the problem:
```julia
p = DSProblem(3);
```
The objective function, initial point, and other parameters may be specified in `DSProblem`:
```julia
obj(x) = x'*[2 1;1 4]*x + x'*[1;4] + 7;
p = DSProblem(2; objective=obj, initial_point=[1.0,2.0]);
```
Note that the objective function is assumed to take a vector of points of points as the input, and return a scalar cost. The initial point should be an array of the same dimensions of the problem, and feasible with respect to any extreme barrier constraints. See `DSProblem`'s documentation for a full list of parameters.

Parameters can also be set after generation of the problem:
```julia
p = DSProblem(2)
SetInitialPoint(p, [1.0,2.0])
SetObjective(p,obj)
SetIterationLimit(p, 500)
```

### Variable Scaling
The range of problem variables can be set with `SetVariableRange` or `SetVariableRanges`. This sets a scale factor that is applied to poll directions before calculating trial poll points. If all variables are of a similar scale and are of a magnitude reasonably close to 10 then the default scaling should be sufficient. 

If a single variable is of a very different order of magnitude, then it can be scaled with `SetVariableRange`. `i` is the index of the variable, and the following numbers are the upper and lower bound of the variable respectively.
```julia
SetVariableRange(p, i, 10000, 20000)
```

The same operation can be applied to all indexes with `SetVariableRanges` (example for N=3):
```julia
SetVariableRanges(p, [10000, -5, -10000], [20000, 5, 10000])
```

Be aware that this **does not** add a constraint on the variable, it **only** creates a scale factor that is applied to generated poll directions. Constraints on variable range should be added explicitly as constraints.

### Optimizing
Run the algorithm with `Optimize!`.
```julia
Optimize!(p)
```
This will run MADS until either the iteration limit (default 1000), or precision limit (`Float64` precision) are reached. The reason for stopping can be accessed as the `status` variable within the problem.
```julia
@show p.status
> p.status = DirectSearch.PrecisionLimit
```
The results can also be found in a similar manner:
```julia
@show p.x
> p.x = [0.0, -0.5]
@show p.x_cost
> p.x_cost = 6.0
```
*(Functions for accessing this data will be added in future.)*

If optimization stopped due to reaching an iteration limit, then the limit can be quickly increased with the `BumpIterationLimit` function:
```julia
BumpIterationLimit(p) #Increments iteration limit by 100 iterations
BumpIterationLimit(p, n) #Increments iteration limit by n iterations
```
And then optimization can be resumed by calling `optimize!` again.

### Type Parameterisation
By default, `DSProblem` is parameterised as `Float64`, but this can be overridden:
```julia
p = DSProblem{Float32}(3);
```
However, this is mostly untested and will almost certainly break. It is included to allow future customisation to be less painful.

## Constraints
Two kinds of constraints are included, progressive barrier, and extreme barrier constraints. As with the objective function, these should be specified as a Julia function that takes a vector, and returns a value. 

### Extreme Barrier Constraints
Extreme barrier constraints are constraints that cannot be violated, and their function should return boolean (true for a feasible point, false for infeasible), or a numerical value giving the constraint violation amount (≤0 for feasible, >0 for infeasible). Added with `AddExtremeConstraint`:

```julia
cons(x) = x[1] > 0 #Constrains x[1] to be larger than 0
AddExtremeConstraint(p, cons)
```

### Progressive Barrier Constraints
Progressive barrier constraints may be violated, transforming the optimization into a dual-objective form that attempts to decrease the amount that the constraint is violated by. Functions that implement a progressive barrier constraint should take a point input and return a numerical value that indicates the constraint violation amount (≤0 for feasible, >0 for infeasible). Added via `AddProgressiveConstraint`:

```julia
cons(x) = x[1] #Constraints x[1] to be less than or equal to 0
AddProgressiveConstraint(p, cons)
```

### Equality Constraints
The package does not care about the form of constraints (as they are treated like a black box). However in many cases, the algorithm will not be able to generate trial points that are exactly able to satisfy equality constraints. 

Therefore, to implement extreme barrier equality constraints a tolerance should be included in the constraint function. Alternatively progressive barrier constraints can be used, but it is likely that the algorithm will not be able to generate feasible solutions, but the final point should be very close to feasible.

### Constraint Indexes
The functions to add a constraint return an index that can be used to refer to the constraints for modification. When supplied with a vector of functions both constraint functions will return a vector of indexes.

Currently these indexes have no direct use. But functions to ignore constraints will be added in future.

### Collections
Constraints are stored in data structures named 'Collections'. Each collection can contain any number of constraints of the same type. By default, extreme barrier constraints are stored in collection one, and progressive barrier constraints in collection two. In most cases, collections can be ignored.

New collections can be created with the following functions:
```julia
AddProgressiveCollection(p);
AddExtremeCollection(p);
```
The collection contains configuration options for the constraints within it. For example, by default the progressive barrier collection uses a square norm when summing constraint violation, this can be configured to use an alternate norm by defining a new collection. See the documentation for the individual functions for all the possible configuration options.

As with adding individual constraints, collections return an index. This is useful for specifying a collection to add a constraint to. These indexes will also be used to refer to the collections for modification in future. 

## Method Choice

MADS defines two stages in each iteration: search and poll. 

### Search

The search stage employs an arbitrary strategy to look for an improved point in the current mesh. This can be designed to take advantage of a known property of the objective function's structure, or be something generic, for example, a random search, or ignored. 

A search step returns a set of points that are then evaluated on the objective function.

The choice of search strategy is set in `DSProblem`:
```julia
p = DSProblem(3; search=RandomSearch(10))
```
The current included search strategies are `NullSearch` and `RandomSearch`. `NullSearch` will perform no search stage and is the default choice. `RandomSearch` will select M random points on the current mesh, where M is the option given to it when instantiated.

### Poll
The poll step is a more rigorously defined exploration in the local space around the incumbent point.

Poll steps return a set of directions that are then evaluated with a preset distance value.

As with the search step, it is set in `DSProblem`:
```julia
p = DSProblem(3; poll=LTMADS())
p = DSProblem(3; poll=OrthoMADS(3))
```
Two poll steps are included. The first is LTMADS, which generates a set of directions from a basis generated from a semi-random lower triangular matrix. The other is OrthoMADS, a later algorithm that generates an orthogonal set of directions. OrthoMADS needs the dimension of the problem to be provided. By default, LTMADS is used.

Note that OrthoMADS is deterministic, therefore using DirectSearch with OrthoMADS will always give the same result (assuming the objective function and constraints are also deterministic). LTMADS has a random element, and will therefore give different results every time it is run. For this reason, LTMADS may need several runs to achieve its best result.

## Custom Algorithms
### Search
Implementing a custom search or poll step is relatively simple. This requires the implementation of a custom type that configures the step, and a corresponding function that implements the stage. For example, a very simple random search around the current incumbent point could be defined with the struct:
```julia
struct RandomLocalSearch <: AbstractSearch
    # Number of points to generate
    N::Int 
    # Maximum distance to explore
    d::Float64
end
```
And then the corresponding implementation with a method of the function `GenerateSearchPoints`:
```julia
function GenerateSearchPoints(p::DSProblem{T}, s::RandomLocalSearch)::Vector{Vector{T}} where T
    points = []
    # Generating s.N points
    for i in 1:s.N
        # Generate offset vector
        offset = zeros(p.N)
        offset[rand(1:p.N)] = rand(-s.d:s.d)
        # Append to points list
        push!(points, p.x + offset)
    end
    # Return list
    return points
end
```
Any implementation of `GenerateSearchPoints` should take and return the shown arguments. This can then be used as with any other Search method:

```julia
p = DSProblem(3; poll=LTMADS(), search=RandomLocalSearch(5, 0.1));
```
Note that this search method it is unlikely to give good results due to not adapting the direction variable `d` to the current mesh size. 

### Poll
A poll step can be implemented in a very similar manner. However, a poll stage should return a direction, not a discrete point. Therefore the function `GenerateDirections` should be overridden instead. As with the search step, this takes the problem as the first argument and the poll type as the second, and returns a vector of directions. A struct configuring a poll type must inherit the `AbstractPoll` type. As an example, please see the file `src/LTMADS.jl`.

Note that, for the convergence properties of MADS to hold, the poll step has several requirements, and therefore it is generally recommended to use LTMADS or OrthoMADS and modify the search stage to fit the objective.

## Future Features
- Orthomads implementation
- More flexible stopping conditions
- Better result/parameter access methods
- Larger variety of search stages
