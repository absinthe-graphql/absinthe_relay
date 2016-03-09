defmodule Absinthe.Relay.NodeTest do
  use ExSpec, async: true

  alias Absinthe.Relay.Node

  defmodule Schema do
    use Absinthe.Schema
    use Absinthe.Relay.Schema

    object :foo do
      field :name, :string
    end

    object :other_foo, name: "FancyFoo" do
      field :name, :string
    end

  end

  describe "to_global_id" do

    it "works given an atom for an existing type" do
      assert !is_nil(Node.to_global_id(:foo, 1, Schema))
    end

    it "returns an atom for an non-existing type" do
      assert is_nil(Node.to_global_id(:not_foo, 1, Schema))
    end

    it "works given a binary and internal ID" do
      assert Node.to_global_id("Foo", 1)
    end

    it "gives the same global ID for different type, equivalent references" do
      assert Node.to_global_id("FancyFoo", 1) == Node.to_global_id(:other_foo, 1, Schema)
    end

    it "gives the different global ID for different type, equivalent references" do
      assert Node.to_global_id("FancyFoo", 1) != Node.to_global_id(:foo, 1, Schema)
    end

    it "fails given a bad ID" do
      assert is_nil(Node.to_global_id("Foo", nil))
    end

  end

end
