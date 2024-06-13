defmodule Item do
  @moduledoc """
  Documentation for Item struct
  """
  defstruct invoice_number: nil,
            description: nil,
            units: nil,
            amount: nil

  def new do
    %Item{}
  end
end
