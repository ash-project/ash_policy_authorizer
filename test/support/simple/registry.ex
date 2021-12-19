defmodule AshPolicyAuthorizer.Test.Simple.Registry do
  @moduledoc false
  use Ash.Registry

  alias AshPolicyAuthorizer.Test.Simple

  entries do
    entry(Simple.User)
    entry(Simple.Organization)
    entry(Simple.Post)
  end
end
