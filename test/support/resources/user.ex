defmodule AshPolicyAuthorizer.Test.User do
  @moduledoc false
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [
      AshPolicyAuthorizer.Authorizer
    ]

  # if you add a policy matching `read` you will need to update the test that checks
  # that an action is unathorized if no policy is defined
  policies do
    policy action_type(:update) do
      authorize_if attribute(:id, eq: actor(:id))
    end
  end

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key(:id)
  end

  actions do
    create(:create)
    read(:read)
    update(:update)
    destroy(:destroy)
  end

  relationships do
    has_many(:memberships, AshPolicyAuthorizer.Test.Membership, destination_field: :user_id)
  end
end
