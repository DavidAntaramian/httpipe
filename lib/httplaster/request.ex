defmodule HTTPlaster.Request do
  @moduledoc ~S"""
  An HTTP request that will be sent to the server

  Note: The functions in this module will typically take an `HTTPlaster.Request` struct
  as their first parameter and return an updated struct. Under most circumstances,
  you will want to use the functions defined in `HTTPlaster.Conn` which take `Conn`
  structs and update internal `Request` structs.
  """

  @typedoc """
  A specifier for the HTTP method

  The standard `GET`, `POST`, `PUT`, `DELETE`, `HEAD`, `OPTIONS`, and `PATCH` methods
  should always be supported by HTTPlaster adapters. The specification also
  allows for non-standard methods to be passed as atoms, and it is advantageous
  for adapters to support these non-standard methods should clients need to connect
  to servers that use them.
  """
  @type http_method :: :get | :post | :put | :delete | :head | :options | :patch | atom

  @typedoc ~S"""
  Specifies a version of HTTP to use. The version should be specified as a `String.t`.

  Currently, HTTPlaster only knows how to support HTTP 1.1 transactions, however,
  HTTP 2 is a future possibility.
  """
  @type http_version :: String.t

  @typdoc ~S"""
  """
  @type url :: String.t

  @typedoc ~S"""
  The body of a request must always be given as a `String.t`, `nil`, or
  `body_encoding`.

  A `nil` body is shorthand for an empty string (`""`) which will be sent
  when the connection is executed.
  """
  @type body :: nil | String.t | body_encoding

  @typedoc ~S"""
  The body encoding specifies a specific way to encode the body
  prior to sending it to the server. It is still the responsibility
  of the consumer to set the appropriate `Content-Type` header.

  ## Sending Files
  
  The `{:file, filename}` option  will cause the file located at `:file` to
  be sent as the body of the request.

  ## Form-Encoding
  
  The `{:form, parameters}` option will cause the parameters (encoded as keyword lists)
  to be sent to be transformed into a `form-urlencoded` value before being
  sent as the body of the request.
  """
  @type body_encoding :: {:file, String.t} | {:form, Keyword.t}

  @typedoc ~S"""
  Headers are stored in a map array of header name (in lower case)
  as a binary to the value as a binary.
  
  For more information, see the documentation for `put_header/4`.
  """
  @type headers :: %{required(String.t) => String.t}

  @type params :: map()

  @type duplicate_options :: :replace_existing | :prefer_existing | :duplicates_ok

  @type t :: %__MODULE__{
               method: http_method,
               http_version: http_version,
               url: String.t,
               headers: headers,
               params: params,
               body: body,
             }

  defstruct method: :get,
            url: nil,
            http_version: "1.1",
            headers: %{},
            params: %{},
            body: nil

  @doc """
  Adds a header to the request

  ## Casing

  Header names are case-insensitive: they may be passed to this function in any
  case; however, in order to aid in de-duplication, header names will be stored
  in lower case.

  ## Duplicate Headers

  Following the guidance of [RFC 2612 4.2](https://www.w3.org/Protocols/rfc2616/rfc2616-sec4.html#sec4.2),
  duplicate headers are accomodated by flattening them into a comma-separated
  list. This is the default behavior. For example,

  ```elixir
  %HTTPlaster.Request{}
  |> Request.put_header("Accept-Encoding", "gzip")
  |> Request.put_header("Accept-Encoding", "deflate")
  ```

  will be flattened to the following header:

  ```text
  Accept-Encoding: gzip, deflate
  ```

  However, this behavior can be changed by specifying a different behavior
  for duplicates as the final parameter. If `replace_existing` is passed,
  the new value will always replace the existing value. If `prefer_existing`
  is passed, the header will only be updated if there is no existing value.
  """
  @spec put_header(t, String.t, String.t, duplicate_options) :: t
  def put_header(request, header_name, header_value, duplication_option \\ :duplicates_ok)

  def put_header(request, header_name, header_value, :duplicates_ok) do
    name = String.downcase(header_name)
    headers = request.headers
              |> Map.update(name, header_value, fn existing ->
                "#{existing}, #{header_value}"
              end)

    %__MODULE__{request | headers: headers}
  end

  def put_header(request, header_name, header_value, :prefer_existing) do
    name = String.downcase(header_name)
    headers = request.headers
              |> Map.put_new(name, header_value)

    %__MODULE__{request | headers: headers}
  end

  def put_header(request, header_name, header_value, :replace_existing) do
    name = String.downcase(header_name)
    headers = request.headers
              |> Map.put(name, header_value)

    %__MODULE__{request | headers: headers}
  end

  @spec put_headers(t, headers) :: t
  def put_headers(request, headers) do
    %__MODULE__{request | headers: headers}
  end

  @spec put_method(t, http_method) :: t
  def put_method(request, method) do
    %__MODULE__{request | method: method}
  end

  @spec put_param(t, String.t | atom, String.t, duplicate_options) :: t
  def put_param(request, param_name, value, duplication_option \\ :replace_existing)

  def put_param(request, param_name, value, :replace_existing) do
    params = request.params
             |> Map.put(param_name, [value])

    %__MODULE__{request | params: params}
  end

  def put_param(request, param_name, value, :duplicates_ok) do
    params =
      request.params
      |> Map.update(param_name, [value], fn existing ->
        [value | existing]
      end)

    %__MODULE__{request | params: params}
  end

  def put_param(request, param_name, value, :prefer_existing) do
    params = request.params
              |> Map.put_new(param_name, [value])

    %__MODULE__{request | params: params}
  end

  @spec put_authentication_basic(t, String.t, String.t) :: t
  def put_authentication_basic(request, username, password) do
    credentials =
      "#{username}:#{password}"
      |> Base.url_encode64(case: :lower)
    
    put_header(request, "Authorization", "Basic #{credentials}", :replace_existing)
  end
  
  @spec put_body(t, body) :: t
  def put_body(request, body) do
    %__MODULE__{request | body: body}
  end

  @spec prepare_url(url, params) :: String.t
  def prepare_url(base_url, params) do
    p =
      Enum.flat_map(params, fn
        # key with multiple values
        # will be encoded as ?key=value1&key=value2 (etc.)
        {key, [values]} when is_list(values) ->
          Enum.map(values, fn v -> {key, v} end)
        # key with a singular value in a list
        # will be encoded as ?key=value
        {key, [value]} ->
          [{key, value}]
      end)
      |> URI.encode_query()

    append_params(base_url, p)
  end

  @spec append_params(url, String.t | params) :: String.t
  defp append_params(url, ""), do: url
  defp append_params(url, params), do: "#{url}?#{params}"

  @spec prepare_body(body, boolean) :: String.t | body
  def prepare_body(body, defer_body_processing)
  def prepare_body(body, true), do: body
  def prepare_body(body, false), do: encode_body(body)

  @spec encode_body(body) :: String.t
  def encode_body(body)

  def encode_body(body) when is_binary(body), do: body
  def encode_body(nil), do: ""
  def encode_body({:form, form_data}), do: URI.encode_query(form_data)

  def encode_body({:file, filename}) do
    {:ok, data} = File.read(filename)
    data
  end

  @doc """
  Sets the URL for the resource to operate on.

  The URL should include the scheme (`http://` or `https://`) as well
  as the fully qualified domain name, and the request path for the
  resource. If necessary, also include the port.

  ## Basic Authentication
  
  If you need to use HTTP Basic authentication, *do not* include the
  username and password as part of the URL. Instead, please use the
  `put_authentication_basic/3` function.
  """
  @spec put_url(t, String.t) :: t
  def put_url(request, url) do
    %__MODULE__{request | url: url}
  end

  @doc """
  Inspects the structure of the Request struct passed in the same
  way `IO.inspect/1` might, returning the Request struct so that it
  can be used easily with pipes.

  Typically, `Kernel.inspect/1`, `IO.inspect/1`, and their companions are
  implemented using the `Inspect` protocol. However, the presentation used
  here can get extremely intrusive when experimenting using IEx, so it's
  relegated to this function. Corresponding functions can be found at
  `HTTPlaster.Conn.inspect/2` and `HTTPlaster.Response.inspect/2`.

  See `HTTPlaster.InspectionHelpers` for more information
  """
  @spec inspect(t, Keyword.t) :: t
  def inspect(req, opts \\ []) do
    opts = struct(Inspect.Opts, opts)

    HTTPlaster.InspectionHelpers.inspect_request(req, opts)
    |> Inspect.Algebra.format(:infinity)
    |> IO.puts()

    req
  end
end
