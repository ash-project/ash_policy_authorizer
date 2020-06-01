defmodule AshPolicyAccess.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :ash_policy_access,
      version: @version,
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:ash, "~> 0.1.2"}
    ]
  end
end
