defmodule HTTPipe.Request.NilURLError do
  @moduledoc """
  Error raised when the URL for a request is `nil`
  """

  @type t :: Exception.t

  defexception message: """
  No URL is specified for the request. The request cannot be completed.
  """

  def exception(_), do: %__MODULE__{}
end
