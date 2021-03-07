defmodule AshPolicyAuthorizer.Check.BuiltInChecks do
  @moduledoc "The global authorization checks built into ash"

  @doc "This check always passes"
  def always do
    {AshPolicyAuthorizer.Check.Static, result: true}
  end

  @doc "this check never passes"
  def never do
    {AshPolicyAuthorizer.Check.Static, result: false}
  end

  @doc "This check is true when the action type matches the provided type"
  def action_type(action_type) do
    {AshPolicyAuthorizer.Check.ActionType, type: action_type}
  end

  @doc "This check is true when the action name matches the provided action name"
  def action(action) do
    {AshPolicyAuthorizer.Check.Action, action: action}
  end

  @doc "This check is true when the field is being selected and false when it is not"
  def selecting(attribute) do
    {AshPolicyAuthorizer.Check.Selecting, attribute: attribute}
  end

  @doc " This check passes if the data relates to the actor via the specified relationship or path of relationships"
  def relates_to_actor_via(relationship_path) do
    {AshPolicyAuthorizer.Check.RelatesToActorVia, relationship_path: List.wrap(relationship_path)}
  end

  @doc "This check is true when a field on the record matches a specific filter"
  def attribute(attribute, filter) do
    {AshPolicyAuthorizer.Check.Attribute, attribute: attribute, filter: filter}
  end

  @doc "This check is true when the value of the specified attribute equals the specified value"
  def actor_attribute_equals(attribute, value) do
    {AshPolicyAuthorizer.Check.ActorAttributeEquals, attribute: attribute, value: value}
  end

  @doc """
  This check is true when attribute changes correspond to the provided options.

  Provide a keyword list of options or just an atom representing the attribute.

  For example:

  ```elixir
  # if you are changing both first name and last name
  changing_attributes(:first_name, :last_name)

  # if you are changing first name to fred
  changing_attributes(first_name: [to: "fred"])

  # if you are changing last name from bob
  changing_attributes(last_name: [from: "bob"])

  # if you are changing :first_name at all, last_name from "bob" and middle name from "tom" to "george"
  changing_attributes([:first_name, last_name: [from: "bob"], middle_name: [from: "tom", to: "george]])
  ```
  """
  def changing_attributes(opts) do
    {AshPolicyAuthorizer.Check.ChangingAttributes, opts}
  end

  @doc "This check is true when the specified relationship is being changed to the current actor"
  def relating_to_actor(relationship) do
    {AshPolicyAuthorizer.Check.RelatingToActor, relationship: relationship}
  end

  @doc "This check is true when the specified relationship is changing"
  def changing_relationship(relationship) do
    changing_relationships(List.wrap(relationship))
  end

  @doc "This check is true when the specified relationships are changing"
  def changing_relationships(relationships) do
    {AshPolicyAuthorizer.Check.ChangingRelationships, relationships: relationships}
  end

  @doc "A helper to build filter templates. Use `actor(:field)` to refer to a field on the actor"
  def actor(field), do: {:_actor, field}
end
