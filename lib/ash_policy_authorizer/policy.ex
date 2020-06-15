defmodule AshPolicyAuthorizer.Policy do
  @moduledoc false
  # For now we just write to `checks` and move them to `policies`
  # on build, when we support nested policies we can change that.
  defstruct [
    :condition,
    :policies,
    :checks,
    :name
  ]

  @doc false
  def transform(%{checks: checks} = policy) do
    {:ok, %{policy | checks: [], policies: checks}}
  end

  @type t :: %__MODULE__{}

  defmodule Check do
    @moduledoc false
    defstruct [:check, :check_module, :check_opts, :type]

    @doc false
    def transform(%{check: {check_module, opts}} = policy) do
      {:ok, %{policy | check_module: check_module, check_opts: opts}}
    end

    @type t :: %__MODULE__{}
  end

  def solve(authorizer) do
    authorizer.policies
    |> build_requirements_expression(authorizer.facts)
    |> AshPolicyAuthorizer.SatSolver.solve()
  end

  defp build_requirements_expression(policies, facts) do
    policy_expression = compile_policy_expression(policies, facts)

    facts_expression =
      AshPolicyAuthorizer.SatSolver.facts_to_statement(Map.drop(facts, [true, false]))

    if facts_expression do
      {:and, facts_expression, policy_expression}
    else
      policy_expression
    end
  end

  def fetch_fact(facts, %{check_module: mod, check_opts: opts}) do
    fetch_fact(facts, {mod, opts})
  end

  def fetch_fact(facts, {mod, opts}) do
    Map.fetch(facts, {mod, opts})
  end

  defp compile_policy_expression(policies, facts)

  defp compile_policy_expression([], _facts) do
    false
  end

  defp compile_policy_expression(
         [%__MODULE__{condition: condition, policies: policies}],
         facts
       ) do
    if is_nil(condition) or match?({:ok, true}, fetch_fact(facts, condition)) do
      compile_policy_expression(policies, facts)
    else
      true
    end
  end

  defp compile_policy_expression(
         [
           %__MODULE__{condition: condition, policies: policies} | rest
         ],
         facts
       ) do
    if is_nil(condition) or match?({:ok, true}, fetch_fact(facts, condition)) do
      {:and, compile_policy_expression(policies, facts), compile_policy_expression(rest, facts)}
    else
      compile_policy_expression(rest, facts)
    end
  end

  defp compile_policy_expression(
         [%{type: :authorize_if} = clause],
         facts
       ) do
    case fetch_fact(facts, clause) do
      {:ok, true} ->
        true

      {:ok, false} ->
        false

      :error ->
        {clause.check_module, clause.check_opts}
    end
  end

  defp compile_policy_expression(
         [%{type: :authorize_if} = clause | rest],
         facts
       ) do
    case fetch_fact(facts, clause) do
      {:ok, true} ->
        true

      {:ok, false} ->
        compile_policy_expression(rest, facts)

      :error ->
        {:or, {clause.check_module, clause.check_opts}, compile_policy_expression(rest, facts)}
    end
  end

  defp compile_policy_expression(
         [%{type: :authorize_unless} = clause],
         facts
       ) do
    case fetch_fact(facts, clause) do
      {:ok, true} ->
        false

      {:ok, false} ->
        true

      :error ->
        {clause.check_module, clause.check_opts}
    end
  end

  defp compile_policy_expression(
         [%{type: :authorize_unless} = clause | rest],
         facts
       ) do
    case fetch_fact(facts, clause) do
      {:ok, true} ->
        compile_policy_expression(rest, facts)

      {:ok, false} ->
        true

      :error ->
        {:or, {clause.check_module, clause.check_opts}, compile_policy_expression(rest, facts)}
    end
  end

  defp compile_policy_expression([%{type: :forbid_if}], _facts) do
    false
  end

  defp compile_policy_expression(
         [%{type: :forbid_if} = clause | rest],
         facts
       ) do
    case fetch_fact(facts, clause) do
      {:ok, true} ->
        false

      {:ok, false} ->
        compile_policy_expression(rest, facts)

      :error ->
        {:and, {:not, clause}, compile_policy_expression(rest, facts)}
    end
  end

  defp compile_policy_expression([%{type: :forbid_unless}], _facts) do
    false
  end

  defp compile_policy_expression(
         [%{type: :forbid_unless} = clause | rest],
         facts
       ) do
    case fetch_fact(facts, clause) do
      {:ok, true} ->
        compile_policy_expression(rest, facts)

      {:ok, false} ->
        false

      :error ->
        {:and, clause, compile_policy_expression(rest, facts)}
    end
  end
end
