defmodule AshPolicyAuthorizer.Check.RelatingToActor do
  @moduledoc "This check is true when the specified relationship is being changed to the current actor"
  use AshPolicyAuthorizer.SimpleCheck

  @impl true
  def describe(opts) do
    "relating this.#{opts[:relationship]} to the actor"
  end

  @impl true
  def match?(nil, _, _), do: false

  def match?(actor, %{changeset: %Ash.Changeset{} = changeset}, opts) do
    resource = changeset.resource
    relationship = Ash.Resource.relationship(resource, opts[:relationship])

    if Ash.Changeset.changing_relationship?(changeset, relationship.name) do
      case Map.get(changeset.relationships, relationship.name) do
        %{replace: replacing} ->
          Enum.any?(List.wrap(replacing), fn replacing ->
            Map.fetch(replacing, relationship.destination_field) ==
              Map.fetch(actor, relationship.destination_field)
          end)

        %{add: adding} ->
          Enum.any?(List.wrap(adding), fn adding ->
            Map.fetch(adding, relationship.destination_field) ==
              Map.fetch(actor, relationship.destination_field)
          end)

        _ ->
          false
      end
    else
      false
    end
  end

  def match?(_, _, _), do: false
end
