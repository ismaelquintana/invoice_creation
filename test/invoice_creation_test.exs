defmodule InvoiceCreationTest do
  use ExUnit.Case
  doctest InvoiceCreation

  test "greets the world" do
    assert InvoiceCreation.hello() == :world
  end

  test "create new invoice" do
    assert Invoice.new() == %Invoice{}
  end

  test "create new bill" do
    assert Bill.new() == %Bill{}
  end
end
