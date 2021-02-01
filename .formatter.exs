local_without_parens = [
  connection: 1,
  payload: 1
]

[
  inputs: ["mix.exs", "{config,lib,test}/**/*.{ex,exs}"],
  import_deps: [:absinthe],
  export: [local_without_parens: local_without_parens]
]
