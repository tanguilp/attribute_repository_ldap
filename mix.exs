defmodule AttributeRepositoryLdap.MixProject do
  use Mix.Project

  def project do
    [
      app: :attribute_repository_ldap,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: [
        main: "readme",
        extras: ["README.md"]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:attribute_repository, path: "../attribute_repository"},
      {:ldapoolex, path: "../ldapoolex"},
      {:nimble_parsec, "~> 0.5"},
      {:timex, "~> 3.1"}, # needed to parse LDAP ISO8601 _basic_ datetime
      {:dialyxir, "~> 1.0.0-rc.4", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false}
    ]
  end
end