defmodule InvoiceCreation.MixProject do
  use Mix.Project

  def project do
    [
      app: :invoice_creation,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      preferred_cli_env: [
        "test.watch": :test
      ],
      test_coverage: [tool: ExCoveralls],
      deps: deps(),
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :wx, :observer, :runtime_tools],
      mod: {InvoiceCreation.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      # {:mix_test_watch, "~> 1.2", only: [:dev, :test], runtime: false},
      {:faker, "~> 0.18.0", only: :test},
      # Database and ORM
      {:ecto_sql, "~> 3.10"},
      {:postgrex, "~> 0.17"},
      {:ecto_sqlite3, "~> 0.12"},
      # CSV handling
      {:csv, "~> 3.2"},
      # Test data factory
      {:ex_machina, "~> 2.7", only: :test},
      {:bandit, "~> 1.0", only: :dev},
      {:tidewave, "~> 0.5.6", only: :dev}
    ]
  end

  defp aliases do
    [
      test: "test --exclude postgres --exclude db",
      tidewave:
        "run --no-halt -e 'Agent.start( fn -> Bandit.start_link(plug: Tidewave, port: 4000) end)'"
    ]
  end
end
