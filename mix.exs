defmodule AshPolicyAccess.MixProject do
  use Mix.Project

  @version "0.1.0"

  @description """
  A policy based access authorizer for the Ash Framework
  """

  def project do
    [
      app: :ash_policy_access,
      version: @version,
      package: package(),
      description: @description,
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      source_url: "https://github.com/ash-project/ash_policy_access",
      homepage_url: "https://github.com/ash-project/ash_policy_access"
    ]
  end

  def package() do
    [
      name: :ash_policy_access,
      licenses: ["MIT"],
      links: %{
        GitHub: "https://github.com/ash-project/ash_policy_access"
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
      {:picosat_elixir, "~> 0.1.1"},
      {:git_ops, "~> 2.0.0", only: :dev},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:ash, "~> 0.1.2"}
    ]
  end
end
