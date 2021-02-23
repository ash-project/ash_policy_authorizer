defmodule AshPolicyAuthorizer.SimpleCheck do
  @moduledoc """
  A type of check that operates only on request context, never on the data

  Simply define `c:match?/3`, which gets the actor, request context, and opts, and returns true or false
  """
  @type authorizer :: AshPolicyAuthorizer.Authorizer.t()
  @type options :: Keyword.t()

  @doc "Whether or not the request matches the check"
  @callback match?(struct(), authorizer(), options) :: boolean

  defmacro __using__(_) do
    quote do
      @behaviour AshPolicyAuthorizer.SimpleCheck
      @behaviour AshPolicyAuthorizer.Check

      def type, do: :simple

      def strict_check(actor, context, opts) do
        {:ok, match?(actor, context, opts)}
      end
    end
  end
end
