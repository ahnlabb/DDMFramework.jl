# DDMFramework

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://ahnlabb.github.io/DDMFramework.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://ahnlabb.github.io/DDMFramework.jl/dev)
[![Build Status](https://github.com/ahnlabb/DDMFramework.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/ahnlabb/DDMFramework.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/ahnlabb/DDMFramework.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/ahnlabb/DDMFramework.jl)

DDMFramework.jl is a Julia package for building and running data-driven microscopy analyses.

## Plugins
A plugin manages updating and querying state for an analysis.

### `MultiPointAnalysis`
The simplest way to create a plugin is to generate a dynamic plugin using
`MultiPointAnalysis`.

``` julia
MultiPointAnalysis(analyisis, name::String, keyfun; keytest=(==))
```

The first argument, `analysis`, is a function that receives an acquired image
and the plugin configuration and should output a julia Table.

The `keyfun` argument is a function used to generate a key from the data sent
by the client. This key is used to differentiate between different
fields-of-view. To test if newly received data belongs to a previously seen
field-of-view the function `keytest` (which defaults to `==`) is used.

The `name` is used when registering the plugin with the server and rendering
results.

#### Example

``` julia
using Images
using DDMFramework
using RegionProps
using DataFrames
using Chain
using SparseArrays
using StatsBase

otsu_segment(img) = img .> otsu_threshold(img)

function filter_objects_in_image(labeled_image, minsize, maxsize)
    sparse_lb = sparse(labeled_image)
    counts = countmap(nonzeros(sparse_lb))
    for (i, j, v) in zip(findnz(sparse_lb)...)
        if counts[v] < minsize || counts[v] > maxsize
            lb[i, j] = 0
        end
    end
    dropzeros!(labeled_image)
end

function simple_segmentation(img; minsize=150, maxsize=2000)
    labeled_image = @chain img begin
        otsu_segment
        label_components
        filter_objects_in_image(_, minsize, maxsize)
    end
    return labeled_image
end

function keyfun(data)::Tuple{Float64}
    x = data["image"].Pixels[:Plane][1][:PositionX]
    y = data["image"].Pixels[:Plane][1][:PositionY]
    return (x,y)
end

function keytest(kleft::Tuple{Float64}, kright::Tuple{Float64})
    atol = 1.2
    isapprox.(kleft,kright;atol) |> all
end

MultiPointAnalysis("NucleusProperties") do image, config
    # Segmentation parameters
    seg_params = config["segmentation"]

    # Segment and filter objects on size in image
    labeled_image = simple_segmentation(image, to_named_tuple(seg_params)...)

    # Extract stats about our objects
    return regionprops(
        image,
        labeled_image;
        selected=unique(nonzeros(labeled_image))
    )
end
```

## Plugin interface
Completely custom plugin logic can be added by defining a struct subtyping
`AbstractPlugin` and fulfilling the plugin interface:

| Method                         | Description            |
|:------------------------------ |:---------------------- |
| `handle_update(state)`         | Returns a tuple of the response (reply to client) as a String and the updated state |
| `query_state(state, query)`    | Returns a String |

The plugin also needs a constructor that takes a `Dict` containing the plugin configuration.
