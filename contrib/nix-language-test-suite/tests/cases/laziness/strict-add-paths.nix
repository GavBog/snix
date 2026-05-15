[
    (./. + "/")
    (./foo + "bar")
    (let name = "bar"; in ./foo + name)
    (let name = "bar"; in ./foo + "${name}")
    (let name = "bar"; in ./foo + "/" + "${name}")
    (let name = "bar"; in ./foo + "/${name}")
    (./. + ./.)
]
