locals_without_parens = [
  connection: 1,
  connection: 2,
  connection: 3
]
[
  inputs: ["mix.exs", "{config,lib,test}/**/*.{ex,exs}"],
  import_deps: [:absinthe],
  locals_without_parens: locals_without_parens
]
