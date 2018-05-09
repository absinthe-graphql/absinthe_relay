defmodule Absinthe.Relay.Connection.Types do
  @moduledoc false

  use Absinthe.Schema.Notation

  object :page_info do
    @desc "When paginating backwards, are there more items?"
    field :has_previous_page, non_null(:boolean)

    @desc "When paginating forwards, are there more items?"
    field :has_next_page, non_null(:boolean)

    @desc "When paginating backwards, the cursor to continue."
    field :start_cursor, :string

    @desc "When paginating forwards, the cursor to continue."
    field :end_cursor, :string
  end
end
