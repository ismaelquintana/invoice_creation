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

  @spec new(description: String.t(), units: integer, amount: integer) :: Item.t()
  def new(description: description, units: units, amount: amount) do
    %Item{description: description, units: units, amount: amount}
  end

  @spec new :: Item.t()
  def new do
    %Item{}
  end
end
