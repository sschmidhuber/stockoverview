#! /usr/bin/env julia

using Pkg

Pkg.add([
"DataFrames",
"JSON",
"LightXML",
"CSV",
"StringBuilders",
"UUIDs",
"Formatting",
"HTTP",
"Bukdu"
])

Pkg.add(PackageSpec(url="https://github.com/JuliaDatabases/Redis.jl"))

exit(0)
