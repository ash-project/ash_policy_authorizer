defmodule AshPolicyAuthorizer.Test.Rbac.Api do
  @moduledoc false
  use Ash.Api

  resources do
    registry(AshPolicyAuthorizer.Test.Rbac.Registry)
  end
end
