defmodule AshPolicyAuthorizer.MixProject do
  @moduledoc false
  use Mix.Project

  @version "0.5.0"

  @description """
  A policy based authorizer for the Ash Framework
  """

  def project do
    [
      app: :ash_policy_authorizer,
      version: @version,
      package: package(),
      description: @description,
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.github": :test
      ],
      aliases: aliases(),
      deps: deps(),
      source_url: "https://github.com/ash-project/ash_policy_authorizer",
      homepage_url: "https://github.com/ash-project/ash_policy_authorizer"
    ]
  end

  def package do
    [
      name: :ash_policy_authorizer,
      licenses: ["MIT"],
      links: %{
        GitHub: "https://github.com/ash-project/ash_policy_authorizer"
      }
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:git_ops, "~> 2.0.0", only: :dev},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:ash, "~> 1.5"},
      {:ex_check, "~> 0.11.0", only: :dev},
      {:credo, ">= 0.0.0", only: :dev, runtime: false},
      {:dialyxir, ">= 0.0.0", only: :dev, runtime: false},
      {:excoveralls, "~> 0.13.0", only: [:dev, :test]},
      {:sobelow, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [
      sobelow: "sobelow --skip",
      credo: "credo --strict",
      "ash.formatter": "ash.formatter --extensions AshPolicyAuthorizer.Authorizer"
    ]
  end
end
