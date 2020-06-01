defmodule AshPolicyAccess.Authorizer do
  defstruct [
    :actor,
    :resource,
    :query,
    :changeset,
    :data,
    :action,
    :api,
    :verbose?,
    :scenarios,
    :check_scenarios,
    :real_scenarios,
    policies: [],
    facts: %{true => true, false => false}
  ]

  @type t :: %__MODULE__{}

  alias AshPolicyAccess.Checker

  @behaviour Ash.Engine.Authorizer

  @impl true
  def initial_state(actor, resource, action, verbose?) do
    %__MODULE__{
      resource: resource,
      actor: actor,
      action: action,
      verbose?: verbose?
    }
  end

  @impl true
  def strict_check_context(_authorizer) do
    # TODO: Figure out what fields we actually need,
    # probably something on the check module
    [:query, :changeset, :api, :resource]
  end

  @impl true
  def check_context(_authorizer) do
    [:query, :changeset, :data, :api, :resource]
  end

  @impl true
  def check(authorizer, context) do
    check_result(%{authorizer | data: context.data})
  end

  @impl true
  def strict_check(authorizer, context) do
    %{
      authorizer
      | query: context.query,
        changeset: context.changeset,
        api: context.api
    }
    |> get_policies()
    |> do_strict_check_facts()
    |> strict_check_result()
  end

  defp strict_filter(authorizer) do
    {filterable, require_check} =
      authorizer.scenarios
      |> Enum.split_with(fn scenario ->
        Enum.all?(scenario, fn {{check_module, opts}, _value} ->
          AshPolicyAccess.Policy.fetch_fact(authorizer.facts, {check_module, opts}) != :error ||
            (Keyword.has_key?(opts, :__auto_filter__) and
               AshPolicyAccess.Check.defines_auto_filter?(check_module))
        end)
      end)

    filter =
      filterable
      |> Enum.reduce([], fn scenario, or_filters ->
        and_filter =
          Enum.reduce(scenario, [], fn {{check_module, check_opts}, value}, and_filters ->
            if check_module.type() == :filter do
              required_status = check_opts[:__auto_filter__] && value

              if required_status do
                check_module.auto_filter(authorizer.actor, authorizer, check_opts)
              else
                [not: check_module.auto_filter(authorizer.actor, authorizer, check_opts)]
              end
            else
              and_filters
            end
          end)

        [and_filter | or_filters]
      end)

    case {filter, require_check} do
      {[], []} ->
        raise "unreachable"

      {_filters, []} ->
        case filter do
          [filter] -> {:filter, filter}
          filters -> {:filter, [or: filters]}
        end

      {_filters, _require_check} ->
        case global_filters(authorizer) do
          nil ->
            {:continue, %{authorizer | check_scenarios: authorizer.scenarios}}

          {filters, scenarios_without_global} ->
            filter =
              case filters do
                [single_filter] -> single_filter
                filters -> [and: filters]
              end

            {:filter_and_continue, filter,
             %{authorizer | check_scenarios: scenarios_without_global}}
        end
    end
  end

  defp global_filters(authorizer, scenarios \\ nil, filter \\ []) do
    scenarios = scenarios || authorizer.scenarios

    global_check_value =
      Enum.find_value(scenarios, fn scenario ->
        Enum.find(scenario, fn {{check_module, opts} = check, value} ->
          check_module.type() == :filter and
            Keyword.has_key?(opts, :__auto_filter__) and
            Enum.all?(scenarios, Map.fetch(scenarios, check) == {:ok, value})
        end)
      end)

    case global_check_value do
      nil ->
        case filter do
          [] -> nil
          filter -> {scenarios, filter}
        end

      {{check_module, check_opts}, value} ->
        required_status = check_opts[:__auto_filter__] && value

        additional_filter =
          if required_status do
            check_module.auto_filter(authorizer.actor, authorizer, check_opts)
          else
            [not: check_module.auto_filter(authorizer.actor, authorizer, check_opts)]
          end

        scenarios = remove_clause(authorizer.scenarios, {check_module, check_opts})
        global_filters(authorizer, scenarios, [additional_filter | filter])
    end
  end

  defp remove_clause(scenarios, clause) do
    Enum.map(scenarios, &Map.delete(&1, clause))
  end

  defp check_result(authorizer) do
    case authorizer.check_scenarios || authorizer.scenarios do
      [] ->
        raise "unreachable"

      [scenario] ->
        case scenario_to_check_filter(scenario, authorizer) do
          {:ok, filter} ->
            {:filter, filter}

          {:error, error} ->
            {:error, error}
        end

      scenarios ->
        result =
          Enum.reduce_while(scenarios, {:ok, []}, fn scenario, {:ok, filters} ->
            case scenario_to_check_filter(scenario, authorizer) do
              {:ok, filter} -> {:cont, {:ok, [filter | filters]}}
              {:error, error} -> {:halt, {:error, error}}
            end
          end)

        case result do
          {:ok, filters} -> {:filter, [or: filters]}
          {:error, error} -> {:error, error}
        end
    end
  end

  defp scenario_to_check_filter(scenario, authorizer) do
    filters =
      Enum.reduce_while(scenario, {:ok, []}, fn {{check_module, check_opts}, required_value},
                                                {:ok, filters} ->
        new_filter =
          case check_module.type() do
            :simple ->
              if AshPolicyAccess.Policy.fetch_fact(scenario.facts, {check_module, check_opts}) !=
                   {:ok, required_value} do
                raise "Assumption failed"
              end

              {:ok, filters}

            :filter ->
              {:ok, check_module.auto_filter(authorizer.actor, authorizer, check_opts)}

            :manual ->
              case check_module.check(authorizer.actor, authorizer.data, authorizer, check_opts) do
                {:ok, true} ->
                  {:ok, nil}

                {:ok, records} ->
                  case Ash.Actions.PrimaryKeyHelpers.values_to_primary_key_filters(
                         authorizer.resource,
                         records
                       ) do
                    [single] -> single
                    pkey_filters -> [or: pkey_filters]
                  end
              end
          end

        case new_filter do
          {:ok, nil} -> {:cont, {:ok, filters}}
          {:ok, new_filter} -> {:cont, {:ok, [new_filter | filters]}}
          {:error, error} -> {:halt, {:error, error}}
        end
      end)

    case filters do
      {:ok, [filter]} -> {:ok, filter}
      {:ok, filters} -> {:ok, [and: filters]}
      {:error, error} -> {:error, error}
    end
  end

  defp strict_check_result(authorizer) do
    case Checker.strict_check_scenarios(authorizer) do
      {:ok, scenarios} ->
        case Checker.find_real_scenarios(scenarios, authorizer.facts) do
          [] ->
            strict_filter(%{authorizer | scenarios: scenarios})

          _real_scenarios ->
            :authorized
        end

      {:error, :unsatisfiable} ->
        {:error,
         AshPolicyAccess.Forbidden.exception(
           verbose?: authorizer.verbose?,
           facts: authorizer.facts,
           scenarios: []
         )}
    end
  end

  defp do_strict_check_facts(authorizer) do
    new_facts = Checker.strict_check_facts(authorizer)

    %{authorizer | facts: new_facts}
  end

  defp get_policies(authorizer) do
    %{authorizer | policies: AshPolicyAccess.policies(authorizer.resource)}
  end
end
