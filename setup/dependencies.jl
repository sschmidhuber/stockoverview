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
"Query",
"Redis",
"Bukdu",
"Gumbo",
"Cascadia"
])

exit(0)
