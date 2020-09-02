defmodule AshPolicyAuthorizer.Check.BuiltInChecks do
  @moduledoc "The global authorization checks built into ash"

  def always do
    {AshPolicyAuthorizer.Check.Static, result: true}
  end

  def never do
    {AshPolicyAuthorizer.Check.Static, result: false}
  end

  def action_type(action_type) do
    {AshPolicyAuthorizer.Check.ActionType, type: action_type}
  end

  def action(action) do
    {AshPolicyAuthorizer.Check.Action, action: action}
  end

  def relates_to_actor_via(relationship_path) do
    {AshPolicyAuthorizer.Check.RelatesToActorVia, relationship_path: List.wrap(relationship_path)}
  end

  def attribute(attribute, filter) do
    {AshPolicyAuthorizer.Check.Attribute, attribute: attribute, filter: filter}
  end

  def actor_attribute_equals(attribute, value) do
    {AshPolicyAuthorizer.Check.ActorAttributeEquals, attribute: attribute, value: value}
  end

  def changing_attributes(opts) do
    {AshPolicyAuthorizer.Check.ChangingAttributes, opts}
  end

  def relating_to_actor(relationship) do
    {AshPolicyAuthorizer.Check.RelatingToActor, relationship: relationship}
  end

  def changing_relationship(relationship) do
    changing_relationships(List.wrap(relationship))
  end

  def changing_relationships(relationships) do
    {AshPolicyAuthorizer.Check.ChangingRelationships, relationships: relationships}
  end

  def actor(field), do: {:_actor, field}
end
