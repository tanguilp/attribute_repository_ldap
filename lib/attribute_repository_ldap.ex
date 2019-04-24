defmodule AttributeRepositoryLdap do
  @moduledoc """
  Read-only implementation of `AttributeRepository` for LDAP servers

  ## Resource id

  The resource id of the `AttributeRepositoryLdap` implementation is the LDAP distinguished
  name (dn)

  ## Run options
  - `:instance`: the `LDAPoolex` pool name (`atom()`). No default, **mandatory**
  - `:base_dn`: the base DN where to perform search. No default, **mandatory** except if
  you only use the `AttributeRepositoryLdap.get/3` and `AttributeRepositoryLdap.get!/3` functions
  - `:search_scope`: scope for LDAP searches. Defaults to `:eldap.singleLevel()`
  - `:search_timeout`: timeout for the search operations (used by `get/3` and `search/3`). No
  default
  """

  require Logger

  use AttributeRepository.Read
  use AttributeRepository.Search

  alias AttributeRepository.Search.AttributePath

  @behaviour AttributeRepository.Read
  @behaviour AttributeRepository.Search

  @data_type_boolean "1.3.6.1.4.1.1466.115.121.1.7"
  @data_type_integer "1.3.6.1.4.1.1466.115.121.1.27"
  @data_type_generalized_time "1.3.6.1.4.1.1466.115.121.1.24"
  @data_type_octet_string "1.3.6.1.4.1.1466.115.121.1.40"

  @impl AttributeRepository.Read

  def get(resource_id, attributes, run_opts) do
    attribute_list =
      case attributes do
        :all ->
          []

        [_ | _] ->
          for attribute <- attributes do
            :erlang.binary_to_list(attribute)
          end
      end

    LDAPoolex.search(run_opts[:instance],
      base: to_charlist(resource_id),
      filter: :eldap.present('objectClass'),
      attributes: attribute_list
    )
    |> process_eldap_search_result(run_opts)
    |> case do
      [{_dn, attributes}] ->
        {:ok, attributes}

      [] ->
        # FIXME: no param to except
        {:error, AttributeRepository.Read.NotFoundError.exception("Entry not found")}
    end
  end

  @impl AttributeRepository.Search

  def search(filter, attributes, run_opts) do
    attribute_list =
      case attributes do
        :all ->
          []

        [_ | _] ->
          for attribute <- attributes do
            :erlang.binary_to_list(attribute)
          end
      end

    eldap_filter = build_eldap_filter(filter)

    IO.inspect(eldap_filter)

    LDAPoolex.search(run_opts[:instance],
      base: to_charlist(run_opts[:base]),
      scope: run_opts[:search_scope] || :eldap.singleLevel(),
      filter: eldap_filter,
      attributes: attribute_list
    )
    |> case do
      {:eldap_search_result, _, _} = result ->
        process_eldap_search_result(result, run_opts)

      {:error, reason} = error ->
        IO.inspect(error)
        {:error, AttributeRepository.ReadError.exception(inspect(reason))}
    end
  end

  @spec build_eldap_filter(AttributeRepository.Search.Filter.t()) :: :eldap.filter()

  defp build_eldap_filter({:attrExp, attrExp}) do
    build_eldap_filter(attrExp)
  end

  defp build_eldap_filter({:and, lhs, rhs}) do
    :eldap.and([
      build_eldap_filter(lhs),
      build_eldap_filter(rhs)
    ])
  end

  defp build_eldap_filter({:or, lhs, rhs}) do
    :eldap.or([
      build_eldap_filter(lhs),
      build_eldap_filter(rhs)
    ])
  end

  defp build_eldap_filter({:not, filter}) do
    filter
    |> build_eldap_filter()
    |> :eldap.not()
  end

  defp build_eldap_filter(
         {:pr,
          %AttributePath{
            attribute: attribute,
            sub_attribute: nil
          }}
       ) do
    attribute
    |> to_charlist()
    |> :eldap.present()
  end

  defp build_eldap_filter(
         {:eq,
          %AttributePath{
            attribute: attribute,
            sub_attribute: nil
          }, value}
       ) do
    attribute
    |> to_charlist()
    |> :eldap.equalityMatch(to_ldap_string_representation(value))
  end

  defp build_eldap_filter(
         {:ne,
          %AttributePath{
            attribute: attribute,
            sub_attribute: nil
          }, value}
       ) do
    attribute
    |> to_charlist()
    |> :eldap.equalityMatch(to_ldap_string_representation(value))
    |> :eldap.not()
  end

  defp build_eldap_filter(
         {:ge,
          %AttributePath{
            attribute: attribute,
            sub_attribute: nil
          }, value}
       ) do
    attribute
    |> to_charlist()
    |> :eldap.greaterOrEqual(to_charlist(value))
  end

  defp build_eldap_filter(
         {:le,
          %AttributePath{
            attribute: attribute,
            sub_attribute: nil
          }, value}
       ) do
    attribute
    |> to_charlist()
    |> :eldap.lessOrEqual(to_ldap_string_representation(value))
  end

  defp build_eldap_filter(
         {:gt,
          %AttributePath{
            attribute: attribute,
            sub_attribute: nil
          }, value}
       ) do
    attribute
    |> to_charlist()
    |> :eldap.lessOrEqual(to_ldap_string_representation(value))
    |> :eldap.not()
  end

  defp build_eldap_filter(
         {:lt,
          %AttributePath{
            attribute: attribute,
            sub_attribute: nil
          }, value}
       ) do
    attribute
    |> to_charlist()
    |> :eldap.greaterOrEqual(to_ldap_string_representation(value))
    |> :eldap.not()
  end

  defp build_eldap_filter(
         {:co,
          %AttributePath{
            attribute: attribute,
            sub_attribute: nil
          }, value}
       ) do
    attribute
    |> to_charlist()
    |> :eldap.substrings(any: to_ldap_string_representation(value))
  end

  defp build_eldap_filter(
         {:sw,
          %AttributePath{
            attribute: attribute,
            sub_attribute: nil
          }, value}
       ) do
    attribute
    |> to_charlist()
    |> :eldap.substrings(initial: to_charlist(value))
  end

  defp build_eldap_filter(
         {:ew,
          %AttributePath{
            attribute: attribute,
            sub_attribute: nil
          }, value}
       ) do
    attribute
    |> to_charlist()
    |> :eldap.substrings(final: to_ldap_string_representation(value))
  end

  @spec process_eldap_search_result(
          {:eldap_search_result, list(), list()},
          AttributeRepository.run_opts()
        ) :: AttributeRepository.resource_list()

  defp process_eldap_search_result({:eldap_search_result, result, _referrals}, run_opts) do
    for {:eldap_entry, dn, attributes} <- result do
      {
        to_string(dn),
        Enum.reduce(
          attributes,
          %{},
          fn
            {name, value}, acc ->
              Map.put(acc, to_string(name), attribute_value_to_string(name, value, run_opts))
          end
        )
      }
    end
  end

  @spec attribute_value_to_string(
          String.t(),
          charlist() | [charlist()],
          AttributeRepository.run_opts()
        ) :: AttributeRepository.attribute_data_type()

  defp attribute_value_to_string(attribute_name, attribute_value, run_opts) do
    case LDAPoolex.Schema.get(run_opts[:instance], to_string(attribute_name)) do
      # no information from schema
      nil ->
        for single_value <- attribute_value do
          to_string(single_value)
        end

      %{single_valued: true, syntax: syntax} ->
        attribute_value
        # theorically, it should be the only element
        |> List.first()
        |> to_elixir_value(syntax)

      %{single_valued: false, syntax: syntax} ->
        for single_value <- attribute_value do
          to_elixir_value(single_value, syntax)
        end
    end
  end

  @spec to_elixir_value(charlist(), binary()) :: AttributeRepository.simple_attribute()

  defp to_elixir_value(value, @data_type_integer <> _), do: :string.to_integer(value) |> elem(0)
  defp to_elixir_value('TRUE', @data_type_boolean <> _), do: true
  defp to_elixir_value('FALSE', @data_type_boolean <> _), do: false

  defp to_elixir_value(value, @data_type_generalized_time <> _),
    do: AttributeRepositoryLdap.Utils.DateParser.to_datetime(to_string(value))

  defp to_elixir_value(value, @data_type_octet_string <> _), do: {:binary_data, value}
  defp to_elixir_value(value, _), do: to_string(value)

  @spec to_ldap_string_representation(AttributeRepository.simple_attribute()) :: [charlist()]

  defp to_ldap_string_representation(val) when is_integer(val), do: to_charlist(val)
  defp to_ldap_string_representation(true), do: 'TRUE'
  defp to_ldap_string_representation(false), do: 'FALSE'

  defp to_ldap_string_representation(%DateTime{} = val),
    do: DateTime.to_iso8601(val, :basic) |> String.replace("T", "") |> to_charlist()

  defp to_ldap_string_representation({:binary_data, bin}), do: to_charlist(bin)
  defp to_ldap_string_representation(nil), do: '\x00'
  defp to_ldap_string_representation(val), do: to_charlist(val)
end
