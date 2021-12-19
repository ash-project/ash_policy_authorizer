defmodule AshPolicyAuthorizer.Test.Simple.Post do
  @moduledoc false
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [
      AshPolicyAuthorizer.Authorizer
    ]

  policies do
    policy action_type(:read) do
      authorize_if expr(author_id == ^actor(:id))
      authorize_if expr(organization.owner_id == ^actor(:id))
    end
  end

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :text, :string do
      allow_nil?(false)
    end
  end

  actions do
    create(:create)
    read(:read)
    update(:update)
    destroy(:destroy)
  end

  relationships do
    belongs_to(:organization, AshPolicyAuthorizer.Test.Simple.Organization)
    belongs_to(:author, AshPolicyAuthorizer.Test.Simple.User)
  end
end
