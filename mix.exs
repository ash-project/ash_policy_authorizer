defmodule AshPolicyAuthorizer.MixProject do
  @moduledoc false
  use Mix.Project

  @version "0.14.4"

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
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.github": :tesxt
      ],
      docs: docs(),
      aliases: aliases(),
      deps: deps(),
      source_url: "https://github.com/ash-project/ash_policy_authorizer",
      homepage_url: "https://github.com/ash-project/ash_policy_authorizer"
    ]
  end

  defp elixirc_paths(:test) do
    ["lib", "test/support"]
  end

  defp elixirc_paths(_), do: ["lib"]

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
      {:git_ops, "~> 2.0.1", only: :dev},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:ash, ash_version("~> 1.34.1")},
      {:ex_check, "~> 0.12.0", only: :dev},
      {:credo, ">= 0.0.0", only: :dev, runtime: false},
      {:dialyxir, ">= 0.0.0", only: :dev, runtime: false},
      {:excoveralls, "~> 0.13.0", only: [:dev, :test]},
      {:sobelow, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp docs do
    # The main page in the docs
    [
      main: "AshPolicyAuthorizer",
      source_ref: "v#{@version}",
      logo: "logos/small-logo.png",
      extra_section: "GUIDES",
      extras: [
        "documentation/writing_policies.md"
      ],
      groups_for_modules: [
        "policy dsl": ~r/AshPolicyAuthorizer.Authorizer/,
        "builtin checks": ~r/AshPolicyAuthorizer.Check\./,
        "custom checks": [
          AshPolicyAuthorizer.Check,
          AshPolicyAuthorizer.FilterCheck,
          AshPolicyAuthorizer.SimpleCheck
        ]
      ]
    ]
  end

  defp ash_version(default_version) do
    case System.get_env("ASH_VERSION") do
      nil -> default_version
      "local" -> [path: "../ash"]
      "master" -> [git: "https://github.com/ash-project/ash.git"]
      version -> "~> #{version}"
    end
  end

  defp aliases do
    [
      sobelow: "sobelow --skip",
      credo: "credo --strict",
      "ash.formatter": "ash.formatter --extensions AshPolicyAuthorizer.Authorizer"
    ]
  end
end
