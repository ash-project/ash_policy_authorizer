defmodule AshPolicyAuthorizer do
  @moduledoc """
  An authorization extension for ash resources.

  For more information, see `AshPolicyAuthorizer.Authorizer`
  """
  @type request :: Ash.Engine.Request.t()
  @type side_load :: {:side_load, Keyword.t()}
  @type prepare_instruction :: side_load

  alias Ash.Dsl.Extension

  def describe_resource(resource) do
    resource
    |> policies()
    |> describe_policies()
  end

  defp describe_policies(policies) do
    Enum.map_join(policies, "\n", fn policy ->
      case policy.condition do
        empty when empty in [nil, []] ->
          describe_checks(policy.policies)

        conditions ->
          "When:\n" <>
            indent(describe_conditions(conditions)) <>
            "\nThen:\n" <> indent(describe_checks(policy.policies))
      end
    end)
  end

  defp describe_checks(checks) do
    checks
    |> Enum.map_join("\n", fn
      %{type: type, check_module: check_module, check_opts: check_opts} ->
        "#{type}: #{check_module.describe(check_opts)}"
    end)
    |> Kernel.<>("\n")
  end

  defp describe_conditions(conditions) do
    Enum.map_join(conditions, " and ", fn
      {check_module, check_opts} ->
        check_module.describe(check_opts)
    end)
  end

  defp indent(string) do
    string
    |> String.split("\n")
    |> Enum.map_join("\n", fn line ->
      "  " <> line
    end)
  end

  def policies(resource) do
    resource
    |> Extension.get_entities([:policies])
    |> set_access_type(default_access_type(resource))
  end

  def default_access_type(resource) do
    Extension.get_opt(resource, [:policies], :default_access_type, :strict, false)
  end

  # This should be done at compile time
  defp set_access_type(policies, default) when is_list(policies) do
    Enum.map(policies, &set_access_type(&1, default))
  end

  defp set_access_type(
         %AshPolicyAuthorizer.Policy{
           policies: policies,
           condition: conditions,
           checks: checks,
           access_type: access_type
         } = policy,
         default
       ) do
    %{
      policy
      | policies: set_access_type(policies, default),
        condition: set_access_type(conditions, default),
        checks: set_access_type(checks, default),
        access_type: access_type || default
    }
  end

  defp set_access_type(%AshPolicyAuthorizer.Policy.Check{check_opts: check_opts} = check, default) do
    %{check | check_opts: Keyword.update(check_opts, :access_type, default, &(&1 || default))}
  end

  defp set_access_type(other, _), do: other
end
