defmodule Item do
  @moduledoc """
  Documentation for Item struct
  """
  defstruct invoice_number: nil,
            description: nil,
            units: nil,
            amount: nil

  @type t :: %__MODULE__{
          invoice_number: String.t() | nil,
          description: String.t() | nil,
          units: integer() | nil,
          amount: integer() | nil
        }

  @spec new :: Item.t()
  def new do
    %Item{}
  end
end
