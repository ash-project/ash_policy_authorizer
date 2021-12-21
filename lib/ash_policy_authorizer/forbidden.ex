defmodule AshPolicyAuthorizer.Forbidden do
  @moduledoc "Raised when authorization for an action fails"

  use Ash.Error.Exception

  def_ash_error([scenarios: [], facts: %{}, filter: nil, verbose?: false], class: :forbidden)

  def report_scenarios(error) do
    error
    |> get_errors()
    |> case do
      [] ->
        "No policy errors"

      errors ->
        errors
        |> Enum.map(fn
          %{filter: filter} when not is_nil(filter) ->
            "Did not match filter expression #{inspect(filter)}"

          %{scenarios: scenarios, facts: facts} ->
            scenarios
            |> Enum.map(fn scenario ->
              scenario
              |> Enum.reject(fn {{module, _}, _} ->
                module == AshPolicyAuthorizer.Check.Static
              end)
              |> Enum.map(fn {{module, opts}, requirement} ->
                [
                  "  ",
                  module.describe(opts) <>
                    " => #{requirement} | #{result({module, opts}, requirement, facts)}"
                ]
              end)
              |> Enum.intersperse("\n")
            end)
        end)
        |> Enum.intersperse("\n\n")
        |> IO.iodata_to_binary()
    end
  end

  defp result(fact, requirement, facts) do
    case facts[fact] do
      ^requirement ->
        "✅"

      _ ->
        "❌"
    end
  end

  defp get_errors(%Ash.Error.Forbidden{errors: errors}) do
    Enum.flat_map(errors || [], fn error ->
      get_errors(error)
    end)
  end

  defp get_errors(%__MODULE__{} = error) do
    [error]
  end

  defp get_errors(_), do: []

  defimpl Ash.ErrorKind do
    def id(_), do: Ecto.UUID.generate()

    def message(%{errors: errors, stacktraces?: stacktraces?}) when not is_nil(errors) do
      Ash.Error.error_messages(errors, nil, stacktraces?)
    end

    def message(error) do
      if error.verbose? do
        description(error)
      else
        "forbidden"
      end
    end

    def code(_), do: "Forbidden"

    def description(%{errors: errors}) when not is_nil(errors) do
      "Forbidden"
    end

    def description(_error) do
      "Forbidden"
    end
  end
end
