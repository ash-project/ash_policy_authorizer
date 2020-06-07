defmodule AshPolicyAccess.Policy do
  defstruct [
    :condition,
    :policies,
    :name
  ]

  defmodule Check do
    defstruct [:check_module, :check_opts, :type]

    def new(type, check_module, check_opts) do
      %__MODULE__{
        type: type,
        check_module: check_module,
        check_opts: check_opts
      }
    end
  end

  def new(condition, policies, name) do
    %__MODULE__{
      name: name,
      condition: condition,
      policies: policies
    }
  end

  def solve(authorizer) do
    expression = build_requirements_expression(authorizer.policies, authorizer.facts)

    expression
    |> add_negations_and_solve()
    |> get_all_scenarios(expression)
    |> case do
      [] ->
        {:error, :unsatisfiable}

      scenarios ->
        {:ok,
         scenarios
         |> Enum.uniq()
         |> remove_irrelevant_clauses()}
    end
  end

  defp get_all_scenarios(scenario_result, expression, scenarios \\ [])
  defp get_all_scenarios({:error, :unsatisfiable}, _, scenarios), do: scenarios

  defp get_all_scenarios({:ok, scenario}, expression, scenarios) do
    expression
    |> add_negations_and_solve([Map.drop(scenario, [true, false]) | scenarios])
    |> get_all_scenarios(expression, [Map.drop(scenario, [true, false]) | scenarios])
  end

  def remove_irrelevant_clauses([scenario]), do: [scenario]

  def remove_irrelevant_clauses(scenarios) do
    new_scenarios =
      scenarios
      |> Enum.uniq()
      |> Enum.map(fn scenario ->
        unnecessary_fact =
          Enum.find_value(scenario, fn
            {fact, value_in_this_scenario} ->
              matching =
                Enum.find(scenarios, fn potential_irrelevant_maker ->
                  potential_irrelevant_maker != scenario &&
                    Map.delete(scenario, fact) == Map.delete(potential_irrelevant_maker, fact)
                end)

              case matching do
                %{^fact => value} when is_boolean(value) and value != value_in_this_scenario ->
                  fact

                _ ->
                  false
              end
          end)

        Map.delete(scenario, unnecessary_fact)
      end)
      |> Enum.uniq()

    if new_scenarios == scenarios do
      scenarios
    else
      remove_irrelevant_clauses(new_scenarios)
    end
  end

  defp add_negations_and_solve(requirements_expression, negations \\ []) do
    negations =
      Enum.reduce(negations, nil, fn negation, expr ->
        negation_statement =
          negation
          |> Map.drop([true, false])
          |> facts_to_statement()

        if expr do
          {:and, expr, {:not, negation_statement}}
        else
          {:not, negation_statement}
        end
      end)

    full_expression =
      if negations do
        {:and, requirements_expression, negations}
      else
        requirements_expression
      end

    Ash.SatSolver.solve_expression(full_expression)
  end

  defp facts_to_statement(facts) do
    Enum.reduce(facts, nil, fn {fact, true?}, expr ->
      expr_component =
        if true? do
          fact
        else
          {:not, fact}
        end

      if expr do
        {:and, expr, expr_component}
      else
        expr_component
      end
    end)
  end

  defp build_requirements_expression(policies, facts) do
    policy_expression = compile_policy_expression(policies, facts)

    facts_expression = facts_to_statement(Map.drop(facts, [true, false]))

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
      IO.inspect(fetch_fact(facts, condition))
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
