defmodule Item do
  @moduledoc """
  Documentation for Item struct
  """
  defstruct description: nil,
            units: nil,
            amount: nil

  @type t :: %__MODULE__{
          description: String.t() | nil,
          units: integer() | nil,
          amount: integer() | nil
        }

  @spec new(keyword()) :: Item.t()
  def new(opts) do
    map =
      opts
      |> Enum.into(%{})

    struct(new(), map)
  end

  @spec new :: Item.t()
  def new do
    %Item{}
  end

  @spec update(Item.t(), keyword()) :: Item.t()
  def update(item, opts) do
    map =
      opts
      |> Enum.into(%{})

    struct(item, map)
  end
end
