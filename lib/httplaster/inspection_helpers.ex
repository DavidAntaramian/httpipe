defmodule HTTPlaster.InspectionHelpers do
  import Inspect.Algebra

  alias HTTPlaster.{Request, Response}

  @spec inspect_header(String.t, String.t) :: String.t
  def inspect_header(k, v) do
    "#{k}: #{v}"
  end

  @spec format_nested_with_header(Inspect.Algebra.t, String.t) :: Inspect.Algebra.t
  def format_nested_with_header(body, header) do
    nested_body =
      line("", body)
      |> nest(2)

    line(header, nested_body)
    |> double_line()
    |> nest(2)
  end

  @spec double_line(Inspect.Algebra.t) :: Inspect.Algebra.t
  def double_line(doc) do
    line("", line("", doc))
  end

  @spec inspect_conn_status(atom) :: Inspect.Algebra.t
  def inspect_conn_status(status) do
    status
    |> Atom.to_string()
    |> String.capitalize()
    |> format_nested_with_header("Status")
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
    Request.prepare_url(base_url, params)
    |> format_nested_with_header("Full URL (with query string)")
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

  @spec inspect_status_code(Response.status_code, Inspect.Opts.t) :: Inspect.Algebra.t
  def inspect_status_code(status_code, opts) do
    status_code
    |> to_doc(opts)
    |> format_nested_with_header("Status Code")
  end
end
