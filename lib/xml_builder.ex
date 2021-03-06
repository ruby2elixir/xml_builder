defmodule XmlBuilder do
  @moduledoc """
  A module for generating XML

  ## Examples

      iex> XmlBuilder.doc(:person)
      "<?xml version=\\\"1.0\\\" encoding=\\\"UTF-8\\\"?>\\n<person/>"

      iex> XmlBuilder.doc(:person, "Josh")
      "<?xml version=\\\"1.0\\\" encoding=\\\"UTF-8\\\"?>\\n<person>Josh</person>"

      iex> XmlBuilder.element(:person, "Josh") |> XmlBuilder.generate
      "<person>Josh</person>"

      iex> XmlBuilder.element(:person, %{occupation: "Developer"}, "Josh") |> XmlBuilder.generate
      "<person occupation=\\\"Developer\\\">Josh</person>"
  """

  defmacrop is_blank_attrs(attrs) do
    quote do: is_blank_map(unquote(attrs)) or is_blank_list(unquote(attrs))
  end

  defmacrop is_blank_list(list) do
    quote do: is_nil(unquote(list)) or (is_list(unquote(list)) and length(unquote(list)) == 0)
  end

  defmacrop is_blank_map(map) do
    quote do: is_nil(unquote(map)) or (is_map(unquote(map)) and map_size(unquote(map)) == 0)
  end

  @doc """
  Generate an XML document.

  Returns a `binary`.

  ## Examples

      iex> XmlBuilder.doc(:person)
      "<?xml version=\\\"1.0\\\" encoding=\\\"UTF-8\\\"?>\\n<person/>"

      iex> XmlBuilder.doc(:person, %{id: 1})
      "<?xml version=\\\"1.0\\\" encoding=\\\"UTF-8\\\"?>\\n<person id=\\\"1\\\"/>"

      iex> XmlBuilder.doc(:person, %{id: 1}, "some data")
      "<?xml version=\\\"1.0\\\" encoding=\\\"UTF-8\\\"?>\\n<person id=\\\"1\\\">some data</person>"
  """
  def doc(elements),
    do: [:xml_decl | elements_with_prolog(elements) |> List.wrap] |> generate

  def doc(name, attrs_or_content),
    do: [:xml_decl | [element(name, attrs_or_content)]] |> generate

  def doc(name, attrs, content),
    do: [:xml_decl | [element(name, attrs, content)]] |> generate

  @doc """
  Create an XML element.

  Returns a `tuple` in the format `{name, attributes, content | list}`.

  ## Examples

      iex> XmlBuilder.element(:person)
      {:person, nil, nil}

      iex> XmlBuilder.element(:person, "data")
      {:person, nil, "data"}

      iex> XmlBuilder.element(:person, %{id: 1})
      {:person, %{id: 1}, nil}

      iex> XmlBuilder.element(:person, %{id: 1}, "data")
      {:person, %{id: 1}, "data"}

      iex> XmlBuilder.element(:person, %{id: 1}, [XmlBuilder.element(:first, "Steve"), XmlBuilder.element(:last, "Jobs")])
      {:person, %{id: 1}, [
        {:first, nil, "Steve"},
        {:last, nil, "Jobs"}
      ]}
  """
  def element(name) when is_bitstring(name),
    do: element({nil, nil, name})

  def element(name) when is_bitstring(name) or is_atom(name),
    do: element({name})

  def element(list) when is_list(list),
    do: Enum.map(list, &element/1)

  def element({name}),
    do: element({name, nil, nil})

  def element({name, attrs}) when is_map(attrs),
    do: element({name, attrs, nil})

  def element({name, content}),
    do: element({name, nil, content})

  def element({name, attrs, content}) when is_list(content),
    do: {name, attrs, Enum.map(content, &element/1)}

  def element({name, attrs, content}),
    do: {name, attrs, content}

  def element(name, attrs) when is_map(attrs),
    do: element({name, attrs, nil})

  def element(name, content),
    do: element({name, nil, content})

  def element(name, attrs, content),
    do: element({name, attrs, content})

  @doc """
  Creates a DOCTYPE declaration with a system identifier.

  Returns a `tuple` in the format `{:doctype, [:system, name, system_identifier}`.

  ## Example

  ```elixir
  import XmlBuilder

  doc([
    doctype("greeting", system: "hello.dtd"),
    element(:person, "Josh")
  ])
  ```

  Outputs

  ```xml
  <?xml version="1.0" encoding="UTF-8" ?>
  <!DOCTYPE greeting SYSTEM "hello.dtd">
  <person>Josh</person>
  ```
  """
  def doctype(name, [{:system, system_identifier}]),
    do: {:doctype, {:system, name, system_identifier}}

  @doc """
  Creates a DOCTYPE declaration with a public identifier.

  Returns a `tuple` in the format `{:doctype, [:public, name, public_identifier, system_identifier}`.  

  ## Example

  ```elixir
  import XmlBuilder

  doc([
    doctype("html", public: ["-//W3C//DTD XHTML 1.0 Transitional//EN",
                  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"]), 
    element(:html, "Hello, world!")
  ])
  ```

  Outputs

  ```xml
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
  <html>Hello, world!</html>
  ```
  """
  def doctype(name, [{:public, [public_identifier, system_identifier]}]),
    do: {:doctype, {:public, name, public_identifier, system_identifier}}

  @doc """
  Generate a binary from an XML tree

  Returns a `binary`.

  ## Examples

      iex> XmlBuilder.generate(XmlBuilder.element(:person))
      "<person/>"

      iex> XmlBuilder.generate({:person, %{id: 1}, "Steve Jobs"})
      "<person id=\\\"1\\\">Steve Jobs</person>"
  """
  def generate(any),
    do: format(any, 0) |> IO.chardata_to_string

  defp format(:xml_decl, 0),
    do: ~s|<?xml version="1.0" encoding="UTF-8"?>|

  defp format({:doctype, {:system, name, system}}, 0),
    do: ['<!DOCTYPE ', to_string(name), ' SYSTEM "', to_string(system), '">']

  defp format({:doctype, {:public, name, public, system}}, 0),
    do: ['<!DOCTYPE ', to_string(name), ' PUBLIC "', to_string(public), '" "', to_string(system), '">']
    
  defp format(string, level) when is_bitstring(string),
    do: format({nil, nil, string}, level)

  defp format(list, level) when is_list(list),
    do: list |> Enum.map(&format(&1, level)) |> Enum.intersperse("\n")

  defp format({nil, nil, name}, level) when is_bitstring(name),
    do: [indent(level), to_string(name)]

  defp format({name, attrs, content}, level) when is_blank_attrs(attrs) and is_blank_list(content),
    do: [indent(level), '<', to_string(name), '/>']

  defp format({name, attrs, content}, level) when is_blank_list(content),
    do: [indent(level), '<', to_string(name), ' ', format_attributes(attrs), '/>']

  defp format({name, attrs, content}, level) when is_blank_attrs(attrs) and not is_list(content),
    do: [indent(level), '<', to_string(name), '>', format_content(content, level+1), '</', to_string(name), '>']

  defp format({name, attrs, content}, level) when is_blank_attrs(attrs) and is_list(content),
    do: [indent(level), '<', to_string(name), '>', format_content(content, level+1), '\n', indent(level), '</', to_string(name), '>']

  defp format({name, attrs, content}, level) when not is_blank_attrs(attrs) and not is_list(content),
    do: [indent(level), '<', to_string(name), ' ', format_attributes(attrs), '>', format_content(content, level+1), '</', to_string(name), '>']

  defp format({name, attrs, content}, level) when not is_blank_attrs(attrs) and is_list(content),
    do: [indent(level), '<', to_string(name), ' ', format_attributes(attrs), '>', format_content(content, level+1), '\n', indent(level), '</', to_string(name), '>']

  defp elements_with_prolog([first | rest]) when length(rest) > 0,
    do: [first_element(first) |element(rest)]

  defp elements_with_prolog(element_spec),
    do: element(element_spec)

  defp first_element({:doctype, args} = doctype_decl) when is_tuple(args),
    do: doctype_decl

  defp first_element(element_spec),
    do: element(element_spec)

  defp format_content(children, level) when is_list(children),
    do: ['\n', Enum.map_join(children, "\n", &format(&1, level))]

  defp format_content(content, _level),
    do: escape(content)

  defp format_attributes(attrs),
    do: Enum.map_join(attrs, " ", fn {name,value} -> [to_string(name), '=', quote_attribute_value(value)] end)

  defp indent(level),
    do: String.duplicate("\t", level)

  defp quote_attribute_value(val) when not is_bitstring(val),
    do: quote_attribute_value(to_string(val))

  defp quote_attribute_value(val) do
    double = String.contains?(val, ~s|"|)
    single = String.contains?(val, "'")
    escaped = escape(val)

    cond do
      double && single ->
        escaped |> String.replace("\"", "&quot;") |> quote_attribute_value
      double -> "'#{escaped}'"
      true -> ~s|"#{escaped}"|
    end
  end

  defp escape({:cdata, data}) do
    ["<![CDATA[", data, "]]>"]
  end

  defp escape(data) when not is_bitstring(data),
    do: escape(to_string(data))

  defp escape(string) do
    string
    |> String.replace(">", "&gt;")
    |> String.replace("<", "&lt;")
    |> replace_ampersand
  end

  defp replace_ampersand(string) do
    Regex.replace(~r/&(?!lt;|gt;|quot;)/, string, "&amp;")
  end
end
