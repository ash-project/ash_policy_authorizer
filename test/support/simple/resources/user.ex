defmodule AshPolicyAuthorizer.Test.Simple.User do
  @moduledoc false
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [
      AshPolicyAuthorizer.Authorizer
    ]

  policies do
    policy action_type(:update) do
      authorize_if expr(id == ^actor(:id))
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
    belongs_to(:organization, AshPolicyAuthorizer.Test.Simple.Organization)
    has_many(:posts, AshPolicyAuthorizer.Test.Simple.Post, destination_field: :author_id)
  end
end
