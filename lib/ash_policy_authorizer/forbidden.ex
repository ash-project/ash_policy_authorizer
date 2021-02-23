defmodule AshPolicyAuthorizer.Forbidden do
  @moduledoc "Raised when authorization for an action fails"

  use Ash.Error.Exception

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
