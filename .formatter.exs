# Used by "mix format"
locals_without_parens = [
  authorize_if: 1,
  forbid_if: 1,
  authorize_unless: 1,
  forbid_unless: 1
]

[
  locals_without_parens: locals_without_parens,
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  export: [
    locals_without_parens: locals_without_parens
  ]
]
