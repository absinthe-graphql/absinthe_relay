defmodule Absinthe.Relay.MutationTest do
  use ExSpec, async: true

  defmodule Schema do
    use Absinthe.Schema
    use Absinthe.Relay.Schema

    mutation do
      payload field :simple_mutation do
        input do
          field :input_data, :integer
        end
        output do
          field :result, :integer
        end
        resolve fn
          %{input_data: input_data}, _ ->
            {:ok, %{result: input_data * 2}}
        end
      end
    end

  end

  describe "mutation_with_client_mutation_id" do

    @query """
    mutation M {
      simpleMutation {
        result
      }
    }
    """
    it "requires an `input' argument" do
      assert {:ok, %{errors: [%{message: "Field `simpleMutation': 1 required argument (`input') not provided"}, %{message: "Argument `input' (SimpleMutationInput): Not provided"}]}} = Absinthe.run(@query, Schema)
    end

    @query """
    mutation M {
      simpleMutation(input: {clientMutationId: "abc", input_data: 1}) {
        result
        clientMutationId
      }
    }
    """
    @expected %{
      data: %{
        "simpleMutation" => %{
          "result" => 2,
          "clientMutationId" => "abc"
        }
      }
    }
    it "returns the same client mutation ID and resolves as expected" do
      assert {:ok, @expected} == Absinthe.run(@query, Schema)
    end
  end


  describe "introspection" do

    @query """
    {
      __type(name: "SimpleMutationInput") {
        name
        kind
        inputFields {
          name
          type {
            name
            kind
            ofType {
              name
              kind
            }
          }
        }
      }
    }
    """
    @expected  %{
      data: %{
        "__type" => %{
          "name" => "SimpleMutationInput",
          "kind" => "INPUT_OBJECT",
          "inputFields" => [
            %{
              "name" => "clientMutationId",
              "type" => %{
                "name" => nil,
                "kind" => "NON_NULL",
                "ofType" => %{
                  "name" => "String",
                  "kind" => "SCALAR"
                }
              }
            },
            %{
              "name" => "inputData",
              "type" => %{
                "name" => "Int",
                "kind" => "SCALAR",
                "ofType" => nil
              }
            }

          ]
        }
      }
    }
    it "contains correct input" do
      assert {:ok, @expected} = Absinthe.run(@query, Schema)
    end

    @query """
    {
      __type(name: "SimpleMutationPayload") {
        name
        kind
        fields {
          name
          type {
            name
            kind
            ofType {
              name
              kind
            }
          }
        }
      }
    }
    """
    @expected %{
      data: %{
        "__type" => %{
          "name" => "SimpleMutationPayload",
          "kind" => "OBJECT",
          "fields" => [
            %{
              "name" => "clientMutationId",
              "type" => %{
                "name" => nil,
                "kind" => "NON_NULL",
                "ofType" => %{
                  "name" => "String",
                  "kind" => "SCALAR"
                }
              }
            },
            %{
              "name" => "result",
              "type" => %{
                "name" => "Int",
                "kind" => "SCALAR",
                "ofType" => nil
              }
            }
          ]
        }
      }
    }

    it "contains correct payload" do
      assert {:ok, @expected} == Absinthe.run(@query, Schema)
    end

  end

  @query """
  {
    __schema {
      mutationType {
        fields {
          name
          args {
            name
            type {
              name
              kind
              ofType {
                name
                kind
              }
            }
          }
          type {
            name
            kind
          }
        }
      }
    }
  }
  """
  @expected %{
    data: %{
      "__schema" => %{
        "mutationType" => %{
          "fields" => [
            %{
              "name" => "simpleMutation",
              "args" => [
                %{
                  "name" => "input",
                  "type" => %{
                    "name" => nil,
                    "kind" => "NON_NULL",
                    "ofType" => %{
                      "name" => "SimpleMutationInput",
                      "kind" => "INPUT_OBJECT"
                    }
                  },
                }
              ],
              "type" => %{
                "name" => "SimpleMutationPayload",
                "kind" => "OBJECT",
              }
            }
          ]
        }
      }
    }
  }

  it "returns the correct field" do
    assert {:ok, @expected} == Absinthe.run(@query, Schema)
  end

end
