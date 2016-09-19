defmodule HTTPipe.Adapter do
  @moduledoc """
  The Adapter behaviour that all adapters must implement
  """

  alias HTTPipe.Request
  alias HTTPipe.Response

  @typedoc ~S"""
  Signature for a successful response from the adapter
  """
  @type success :: {:ok, response}

  @typedoc ~S"""
  Signature for a failed response from the adapter
  """
  @type failure :: {:error, exception}

  @typedoc ~S"""
  When an adapter fails, it must respond with a valid exception that can
  be raised
  """
  @type exception :: Exception.t

  @typedoc ~S"""
  The adapter must return the status code, the headers, and the body
  for the response
  """
  @type response :: {Response.status_code, Response.headers, Response.body}

  @typedoc ~S"""
  The adapter may take certain options that will be passed as the final
  parameter as a Keyword list. The adapter documentation should list the
  possible options and their usage.
  """
  @type options :: Keyword.t

  @doc """
  Called by `HTTPipe.Conn` to execute a request and receive a response

  This interface is designed to be as simple as possible, so it only has
  five components to it. Implementers should take care, however, to read
  up on the expectations of each parameter, especially the body parameter.

  The typespecs for each parameter will describe the expectations of those
  parameters and ways in which those expectations can be modified.

  For example, the body parameter accepts tuples to specify special forms.
  Normally, HTTPipe will handle these tuples prior to calling
  the adapter's `execute_request/5` method. However, if there are special
  considerations or your adapter wants to handle these tuples natively,
  you can defer the processing of the body parameter and have it passed
  in its original form by specifying the configuration value
  `defer_body_processing` as `true`. (If you utilize this, you can
  call HTTPipe's helper functions that it would normally call
  for any tuple forms you cannot natively handle.)
  """
  @callback execute_request(
    Request.http_method,
    Request.url,
    Request.body,
    Request.headers,
    options
  ) :: success | failure
end
