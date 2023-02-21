defmodule Absinthe.Relay.Mutation.ModernTest do
  use Absinthe.Relay.Case, async: true

  defmodule SchemaWithInputAndOutput do
    use Absinthe.Schema
    use Absinthe.Relay.Schema, :modern

    query do
      # cannot have empty query type
      field :simple_query, :integer, resolve: fn _, _ -> {:ok, 1} end
    end

    mutation do
      payload field(:simple_mutation) do
        input do
          field :input_data, :integer
        end

        output do
          field :result, :integer
        end

        resolve fn
          %{input_data: input_data}, _ ->
            {:ok, %{result: input_data * 2}}

          %{}, _ ->
            {:ok, %{result: 1}}
        end
      end
    end
  end

  describe "mutation field with input declaration" do
    @query """
    mutation M {
      simpleMutation {
        result
      }
    }
    """
    test "requires the input argument" do
      assert {:ok,
              %{
                errors: [
                  %{
                    message:
                      "In argument \"input\": Expected type \"SimpleMutationInput!\", found null."
                  }
                ]
              }} = Absinthe.run(@query, SchemaWithInputAndOutput)
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
    test "resolves SchemaWithInputAndOutput" do
      assert {:ok, @expected} == Absinthe.run(@query, SchemaWithInputAndOutput)
    end
  end

  describe "__type introspection on SchemaWithInputAndOutput" do
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
    @expected %{
      data: %{
        "__type" => %{
          "name" => "SimpleMutationInput",
          "kind" => "INPUT_OBJECT",
          "inputFields" => [
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
    test "contains correct input type" do
      assert {:ok, @expected} = Absinthe.run(@query, SchemaWithInputAndOutput)
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
    test "contains correct payload type" do
      assert {:ok, @expected} == Absinthe.run(@query, SchemaWithInputAndOutput)
    end
  end

  describe "__schema introspection for SchemaWithInputAndOutput" do
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
                    }
                  }
                ],
                "type" => %{
                  "name" => "SimpleMutationPayload",
                  "kind" => "OBJECT"
                }
              }
            ]
          }
        }
      }
    }

    test "returns the correct field" do
      assert {:ok, @expected} == Absinthe.run(@query, SchemaWithInputAndOutput)
    end
  end

  defmodule SchemaWithInputAndOutputReversed do
    use Absinthe.Schema
    use Absinthe.Relay.Schema, :modern

    query do
      # cannot have empty query type
      field :simple_query, :integer, resolve: fn _, _ -> {:ok, 1} end
    end

    mutation do
      payload field(:simple_mutation) do
        output do
          field :result, :integer
        end

        resolve fn
          %{input_data: input_data}, _ ->
            {:ok, %{result: input_data * 2}}

          %{}, _ ->
            {:ok, %{result: 1}}
        end

        input do
          field :input_data, :integer
        end
      end
    end
  end

  describe "mutation field with input declaration at end" do
    @query """
    mutation M {
      simpleMutation {
        result
      }
    }
    """
    test "requires the input argument" do
      assert {:ok,
              %{
                errors: [
                  %{
                    message:
                      "In argument \"input\": Expected type \"SimpleMutationInput!\", found null."
                  }
                ]
              }} = Absinthe.run(@query, SchemaWithInputAndOutputReversed)
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
    test "resolves SchemaWithInputAndOutputReversed" do
      assert {:ok, @expected} == Absinthe.run(@query, SchemaWithInputAndOutputReversed)
    end
  end

  describe "__type introspection on SchemaWithInputAndOutputReversed" do
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
    @expected %{
      data: %{
        "__type" => %{
          "name" => "SimpleMutationInput",
          "kind" => "INPUT_OBJECT",
          "inputFields" => [
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
    test "contains correct input type" do
      assert {:ok, @expected} = Absinthe.run(@query, SchemaWithInputAndOutputReversed)
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
    test "contains correct payload type" do
      assert {:ok, @expected} == Absinthe.run(@query, SchemaWithInputAndOutputReversed)
    end
  end

  describe "__schema introspection for SchemaWithInputAndOutputReversed" do
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
                    }
                  }
                ],
                "type" => %{
                  "name" => "SimpleMutationPayload",
                  "kind" => "OBJECT"
                }
              }
            ]
          }
        }
      }
    }

    test "returns the correct field" do
      assert {:ok, @expected} == Absinthe.run(@query, SchemaWithInputAndOutputReversed)
    end
  end

  defmodule SchemaWithOutputButNoInput do
    use Absinthe.Schema
    use Absinthe.Relay.Schema, :modern

    query do
      # cannot have empty query type
      field :simple_query, :integer, resolve: fn _, _ -> {:ok, 1} end
    end

    mutation do
      payload field(:simple_mutation) do
        output do
          field :result, :integer
        end

        resolve fn _, _ -> {:ok, %{result: 1}} end
      end
    end
  end

  describe "executing for SchemaWithOutputButNoInput" do
    @query """
    mutation M {
      simpleMutation {
        result
      }
    }
    """
    @expected %{
      data: %{
        "simpleMutation" => %{
          "result" => 1
        }
      }
    }
    test "resolves as expected" do
      assert {:ok, @expected} == Absinthe.run(@query, SchemaWithOutputButNoInput)
    end
  end

  describe "__type introspection on SchemaWithOutputButNoInput" do
    @query """
    {
      __type(name: "SimpleMutationInput") {
        name
      }
    }
    """
    @expected %{
      data: %{
        "__type" => nil
      }
    }
    test "return nil for the input type" do
      assert {:ok, @expected} = Absinthe.run(@query, SchemaWithOutputButNoInput)
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
      assert {:ok, @expected} == Absinthe.run(@query, SchemaWithOutputButNoInput)
    end
  end

  describe "__schema introspection on SchemaWithOutputButNoInput" do
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
                "args" => [],
                "type" => %{
                  "name" => "SimpleMutationPayload",
                  "kind" => "OBJECT"
                }
              }
            ]
          }
        }
      }
    }

    test "returns the correct field" do
      assert {:ok, @expected} == Absinthe.run(@query, SchemaWithOutputButNoInput)
    end
  end
end
