defmodule Vault.MixProject do
  use Mix.Project

  def project do
    [
      app: :vault,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      erlc_paths: ["src"],
      test_pattern: "*_SUITE.erl",
      dialyzer: [
        plt_add_apps: [:eunit, :common_test]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {:vault_app, []}
    ]
  end

  defp deps do
    [
      # CouchDB client for Erlang
      {:couchbeam, "~> 1.4"}
      
      # TODO: Use {:enacl, "~> 1.2"} for cryptography after fixing Erlang compatibility
    ]
  end
end
