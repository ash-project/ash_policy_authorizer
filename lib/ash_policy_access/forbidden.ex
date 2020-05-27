defmodule AshPolicyAccess.Forbidden do
  @moduledoc "Raised when authorization for an action fails"

  use Ash.Error

  # alias AshPolicyAccess.Report

  def_ash_error([scenarios: [], facts: %{}, verbose?: false], class: :forbidden)

  defimpl Ash.ErrorKind do
    def id(_), do: Ecto.UUID.generate()

    def message(%{errors: errors}) when not is_nil(errors) do
      Ash.Error.error_messages(errors)
    end

    def message(error) do
      if error.verbose? do
        description(error)
      else
        "forbidden by policy"
      end
    end

    def code(_), do: "ForbiddenByPolicy"

    def description(%{errors: errors}) when not is_nil(errors) do
      # report = %Report{
      #   api: error.api,
      #   scenarios: error.scenarios,
      #   requests: error.requests,
      #   facts: error.facts,
      #   state: error.state,
      #   no_steps_configured: error.no_steps_configured,
      #   header: "forbidden by policy:",
      #   authorized?: false
      # }

      # Report.report(report)

      # Ash.Error.error_descriptions(errors)
      "Forbidden"
    end

    def description(_error) do
      "Forbidden"
    end
  end
end
