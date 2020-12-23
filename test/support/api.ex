defmodule AshPolicyAuthorizer.Test.Api do
  @moduledoc false
  use Ash.Api
  alias AshPolicyAuthorizer.Test

  resources do
    resource(Test.User)
    resource(Test.Organization)
    resource(Test.Membership)
    resource(Test.File)
  end
end
