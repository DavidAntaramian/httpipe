defmodule HTTPipe.InspectionHelpers do
  @moduledoc """
  Helper module for formatting `HTTPipe.Conn`, `HTTPipe.Request`, and `HTTPipe.Response`
  structs.

  This module offers a way to nicely report the state of `Conn`, `Request`, and `Response`
  structs using standard `Inspect.Algebra` documents, however the result is far too intrusive
  to be used as the default protocol implementation. Therefore, each module has an individual
  `inspect/2` function that can be called which will display the output:

    - `HTTPipe.Conn.inspect/2`
    - `HTTPipe.Request.inspect/2`
    - `HTTPipe.Response.inspect/2`
  """

  import Inspect.Algebra

  alias HTTPipe.{Conn, Request, Response}

  @doc """
  """
  @spec inspect_conn(Conn.t, Inspect.Opts.t) :: Inspect.Algebra.t
  def inspect_conn(conn, opts) do
    status_doc =
      conn.status
      |> inspect_conn_status(opts)

    error_doc =
      conn.error
      |> inspect_error(opts)

    options_doc =
      conn.options
      |> to_doc(opts)
      |> format_nested_with_header("Options")

    adapter_doc =
      conn.adapter
      |> to_doc(opts)
      |> format_nested_with_header("Adapter")

    adapter_options_doc =
      conn.adapter_options
      |> to_doc(opts)
      |> format_nested_with_header("Adapter Options")

    request_doc =
      conn.request
      |> inspect_request(opts)
      |> double_line_break()
      |> nest(2)

    response_doc =
      conn.response
      |> inspect_response(opts)
      |> double_line_break()
      |> nest(2)

    concat [
      format_section_head("Conn"),
      status_doc,
      error_doc,
      options_doc,
      adapter_doc,
      adapter_options_doc,
      request_doc,
      response_doc
    ]
  end

  @spec inspect_request(nil | Request.t, Inspect.Opts.t) :: Inspect.Algebra.t
  def inspect_request(request, opts) do
    headers = inspect_headers(request.headers)
    http_version = inspect_http_version(request.http_version, opts)
    method = inspect_method(request.method)
    url = inspect_url(request.url, opts)
    full_url = inspect_full_url(request.url, request.params, opts)
    params = inspect_params(request.params, opts)
    body = inspect_body(request.body, opts)
    curl_string = inspect_curl_string(request, opts)

    concat [
      format_section_head("Request"),
      http_version,
      method,
      url,
      full_url,
      headers,
      params,
      body,
      curl_string
    ]
  end

  @spec inspect_response(Response.t, Inspect.Opts.t) :: Inspect.Algebra.t
  def inspect_response(nil, _opts) do
    empty()
  end

  def inspect_response(response, opts) do
    status_code = inspect_status_code(response.status_code, opts)
    headers = inspect_headers(response.headers)
    body = inspect_body(response.body, opts)

    concat [
      format_section_head("Response"),
      status_code,
      headers,
      body
    ]
  end

  @spec inspect_header(String.t, String.t) :: String.t
  def inspect_header(k, v) do
    "#{k}: #{v}"
  end

  @spec inspect_error(nil | Conn.exception, Inspect.Opts.t) :: Inspect.Algebra.t

  def inspect_error(nil, _), do: empty()

  def inspect_error(error, opts) do
    error
    |> to_doc(opts)
    |> format_nested_with_header("Error", :error)
  end

  @spec inspect_conn_status(atom, Inspect.Opts.t) :: Inspect.Algebra.t
  def inspect_conn_status(status, _opts) do
    ansify_status(status)
    |> format_nested_with_header("Status")
  end

  @spec ansify_status(Conn.status) :: String.t
  defp ansify_status(:executed) do
    IO.ANSI.format([:green, ":executed"])
    |> IO.iodata_to_binary()
  end

  defp ansify_status(:unexecuted) do
    IO.ANSI.format([:yellow, ":unexecuted"])
    |> IO.iodata_to_binary()
  end

  defp ansify_status(:failed) do
    IO.ANSI.format([:red, ":failed"])
    |> IO.iodata_to_binary()
  end

  @spec inspect_url(Request.url, Inspect.Opts.t) :: Inspect.Algebra.t
  def inspect_url(nil, opts) do
    to_doc(nil, opts)
    |> format_nested_with_header("URL")
  end

  def inspect_url(url, _) do
    format_nested_with_header(url, "URL")
  end

  @spec inspect_full_url(Request.url, Request.params, Inspect.Opts.t) :: Inspect.Algebra.t
  def inspect_full_url(nil, _, opts) do
    to_doc(nil, opts)
    |> format_nested_with_header("Full URL (with query string)")
  end

  def inspect_full_url(base_url, params, _) do
    {:ok, full_url} = Request.prepare_url(base_url, params)
    format_nested_with_header(full_url, "Full URL (with query string)")
  end

  @spec inspect_http_version(Request.http_version, Inspect.Opts.t) :: Inspect.Algebra.t
  def inspect_http_version(version, opts) do
    to_doc(version, opts)
    |> format_nested_with_header("HTTP Version")
  end

  @spec inspect_params(Request.params, Inspect.Opts.t) :: Inspect.Algebra.t
  def inspect_params(params, opts) do
    params
    |> to_doc(opts)
    |> format_nested_with_header("URL Parameters")
  end

  @spec inspect_method(Request.http_method) :: Inspect.Algebra.t
  def inspect_method(method) do
    method
    |> Atom.to_string()
    |> String.upcase()
    |> format_nested_with_header("HTTP Method")
  end

  @spec inspect_body(Request.body, Inspect.Opts.t) :: Inspect.Algebra.t
  def inspect_body(body, opts) do
    body
    |> to_doc(opts)
    |> format_nested_with_header("Body")
  end

  @spec inspect_headers(Request.headers | Response.headers) :: Inspect.Algebra.t
  def inspect_headers(headers) when map_size(headers) == 0 do
    format_nested_with_header("(none)", "Headers")
  end

  def inspect_headers(headers) do
    headers
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.reduce(nil, fn
         {k, v}, nil ->
           inspect_header(k, v)
         {k, v}, existing_doc ->
           line(existing_doc, inspect_header(k, v))
       end)
    |> format_nested_with_header("Headers")
  end

  @spec inspect_curl_string(Request.t, Inspect.Opts.t) :: Inspect.Algebra.t
  def inspect_curl_string(request, opts) do
    request
    |> Request.to_curl()
    |> to_doc(opts)
    |> format_nested_with_header("Curl String")
  end

  @spec inspect_status_code(Response.status_code, Inspect.Opts.t) :: Inspect.Algebra.t
  def inspect_status_code(status_code, opts) do
    status_code
    |> to_doc(opts)
    |> format_nested_with_header("Status Code")
  end

  @doc """
  Inserts two lines above the algebra document for spacing
  """
  @spec double_line_break(Inspect.Algebra.t) :: Inspect.Algebra.t
  def double_line_break(doc) do
    lower_line = line("", doc)
    line("", lower_line)
  end

  @spec format_nested_with_header(Inspect.Algebra.t, String.t, atom) :: Inspect.Algebra.t
  def format_nested_with_header(body, header, type \\ :default)

  def format_nested_with_header(body, header, :default) do
    nested_body =
      line("", body)
      |> nest(2)

    IO.ANSI.format([:blue, header])
    |> IO.iodata_to_binary()
    |> line(nested_body)
    |> double_line_break()
    |> nest(2)
  end

  def format_nested_with_header(body, header, :error) do
    nested_body =
      line("", body)
      |> nest(2)

    IO.ANSI.format([:red, header])
    |> IO.iodata_to_binary()
    |> line(nested_body)
    |> double_line_break()
    |> nest(2)
  end

  @spec format_section_head(String.t) :: String.t
  def format_section_head(header) do
    IO.ANSI.format([:underline, :yellow, header])
    |> IO.iodata_to_binary()
  end
end
