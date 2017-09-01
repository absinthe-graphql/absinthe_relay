defmodule Absinthe.Relay.Mutation.ModernTest do
  use Absinthe.Relay.Case, async: true

  defmodule Schema do
    use Absinthe.Schema
    use Absinthe.Relay.Schema, :modern

    query do
    end

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

  describe "mutation with clientMutationId" do

    @query """
    mutation M {
      simpleMutation {
        result
      }
    }
    """
    test "requires an `input' argument" do
      assert {:ok, %{errors: [%{message: ~s(In argument "input": Expected type "SimpleMutationInput!", found null.)}]}} = Absinthe.run(@query, Schema)
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
    test "returns the same client mutation ID and resolves as expected" do
      assert {:ok, @expected} == Absinthe.run(@query, Schema)
    end
  end

  describe "mutation WITHOUT clientMutationId" do

    @query """
    mutation M {
      simpleMutation {
        result
      }
    }
    """
    test "requires an `input' argument" do
      assert {:ok, %{errors: [%{message: ~s(In argument "input": Expected type "SimpleMutationInput!", found null.)}]}} = Absinthe.run(@query, Schema)
    end

    @query """
    mutation M {
      simpleMutation(input: {input_data: 1}) {
        result
        clientMutationId
      }
    }
    """
    @expected %{
      data: %{
        "simpleMutation" => %{
          "result" => 2,
          "clientMutationId" => nil
        }
      }
    }
    test "returns nil clientMutationId" do
      assert {:ok, @expected} == Absinthe.run(@query, Schema)
    end

    @query """
    mutation M {
      simpleMutation(input: {input_data: 1}) {
        result
      }
    }
    """
    @expected %{
      data: %{
        "simpleMutation" => %{
          "result" => 2
        }
      }
    }
    test "works without querying clientMutationId in the payload" do
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
                "name" => "String",
                "kind" => "SCALAR",
                "ofType" => nil
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
    test "contains correct input" do
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
                "name" => "String",
                "kind" => "SCALAR",
                "ofType" => nil
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

    test "contains correct payload" do
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

  test "returns the correct field" do
    assert {:ok, @expected} == Absinthe.run(@query, Schema)
  end

  describe "an empty definition" do

    defmodule EmptyInputAndResultSchema do
      use Absinthe.Schema
      use Absinthe.Relay.Schema, :modern

      query do

      end

      mutation do
        payload field :without_block, resolve: fn _, _ -> {:ok, %{}} end
        payload field :with_block_and_attrs, resolve: (fn _, _ -> {:ok, %{}} end) do
        end
        payload field :with_block do
          resolve fn
            _, _ ->
              # Logic is there
              {:ok, %{}}
          end
        end
      end

    end

    @cm_id "abc"

    @query """
    mutation M {
      withoutBlock(input: {clientMutationId: "#{@cm_id}"}) {
        clientMutationId
      }
    }
    """
    test "supports returning the client mutation id intact when defined without a block" do
      assert {:ok, %{data: %{"withoutBlock" => %{"clientMutationId" => @cm_id}}}} == Absinthe.run(@query, EmptyInputAndResultSchema)
    end

    @query """
    mutation M {
      withBlock(input: {clientMutationId: "#{@cm_id}"}) {
        clientMutationId
      }
    }
    """
    test "supports returning the client mutation id intact when defined with a block" do
      assert {:ok, %{data: %{"withBlock" => %{"clientMutationId" => @cm_id}}}} == Absinthe.run(@query, EmptyInputAndResultSchema)
    end

    @query """
    mutation M {
      withBlockAndAttrs(input: {clientMutationId: "#{@cm_id}"}) {
        clientMutationId
      }
    }
    """
    test "supports returning the client mutation id intact when defined with a block and attrs" do
      assert {:ok, %{data: %{"withBlockAndAttrs" => %{"clientMutationId" => @cm_id}}}} == Absinthe.run(@query, EmptyInputAndResultSchema)
    end


  end



end
