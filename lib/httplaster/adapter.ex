defmodule HTTPlaster.Adapter do
  @moduledoc """
  The Adapter behaviour that all adapters must implement
  """

  alias HTTPlaster.Request
  alias HTTPlaster.Response

  @typedoc ~S"""

  """
  @type success :: {:ok, response}
  
  @typedoc ~S"""
  """
  @type failure :: {:error, exception}

  @typedoc ~S"""
  """
  @type exception :: Exception.t

  @typedoc ~S"""
  """
  @type response :: {Response.status_code, Response.headers, Response.body}

  @typedoc ~S"""

  """
  @type options :: Keyword.t

  @doc """
  Called by `HTTPlaster.Conn` to execute a request and receive a response

  This interface is designed to be as simple as possible, so it only has
  five components to it. Implementers should take care, however, to read
  up on the expectations of each parameter, especially the body parameter.

  The typespecs for each parameter will describe the expectations of those
  parameters and ways in which those expectations can be modified.

  For example, the body parameter accepts tuples to specify special forms.
  Normally, HTTPlaster will handle these tuples prior to calling
  the adapter's `execute_request/5` method. However, if there are special
  considerations or your adapter wants to handle these tuples natively,
  you can defer the processing of the body parameter and have it passed
  in its original form by specifying the configuration value
  `defer_body_processing` as `true`. (If you utilize this, you can
  call HTTPlaster's helper functions that it would normally call
  for any tuple forms you cannot natively handle.)
  """
  @callback execute_request(
    Request.http_method,
    String.t,
    Request.body,
    Request.headers,
    options
  ) :: success | failure
end
