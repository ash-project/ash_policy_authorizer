defmodule AshPolicyAuthorizer.Test.Registry do
  @moduledoc false
  use Ash.Registry

  alias AshPolicyAuthorizer.Test

  entries do
    entry(Test.User)
    entry(Test.Organization)
    entry(Test.Membership)
    entry(Test.File)
  end
end
