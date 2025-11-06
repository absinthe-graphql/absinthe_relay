defmodule Absinthe.Relay.Mutation.DefaultInputDescriptionTest do
  use Absinthe.Relay.Case, async: true

  defmodule Schema do
    use Absinthe.Schema
    use Absinthe.Relay.Schema, :modern

    query do
      field :dummy, :string
    end

    mutation do
      payload field(:create_user) do
        @desc "User creation parameters"
        input do
          field(:name, :string)
          field(:email, :string)
        end
        output do
          field(:user, :string)
        end
        resolve fn _, _ -> {:ok, %{user: "created"}} end
      end

      payload field(:update_post_settings) do
        input do
          description "Settings for updating a post"
          field(:post_id, :id)
          field(:settings, :string)
        end
        output do
          field(:success, :boolean)
        end
        resolve fn _, _ -> {:ok, %{success: true}} end
      end
      
      payload field(:remove_pending_engagements) do
        input do
          field(:gig_id, :id)
        end
        output do
          field(:result, :string)
        end
        resolve fn _, _ -> {:ok, %{result: "ok"}} end
      end
    end
  end

  test "input arguments inherit descriptions from input types" do
    {:ok, %{data: data}} = Absinthe.run("""
    {
      __type(name: "RootMutationType") {
        fields {
          name
          args {
            name
            description
          }
        }
      }
    }
    """, Schema)
    
    fields = data["__type"]["fields"]
    
    # Check createUser mutation - should use @desc from input type
    create_user = Enum.find(fields, &(&1["name"] == "createUser"))
    create_user_input = Enum.find(create_user["args"], &(&1["name"] == "input"))
    assert create_user_input["description"] == "User creation parameters"
    
    # Check updatePostSettings mutation - should use description macro from input type
    update_post = Enum.find(fields, &(&1["name"] == "updatePostSettings"))
    update_post_input = Enum.find(update_post["args"], &(&1["name"] == "input"))
    assert update_post_input["description"] == "Settings for updating a post"
    
    # Check removePendingEngagements mutation - should be nil (no description on input type)
    remove_pending = Enum.find(fields, &(&1["name"] == "removePendingEngagements"))
    remove_pending_input = Enum.find(remove_pending["args"], &(&1["name"] == "input"))
    assert remove_pending_input["description"] == nil
  end
end