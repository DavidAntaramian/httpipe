defmodule HTTPipe.Conn.AlreadyExecutedError do
  @moduledoc """
  This exception is raised when the Conn you are executing has already
  been executed.
  """

  @type t :: Exception.t

  defexception message: """
  The Conn has already been executed.

  Executing a Conn will sometimes change the Request which can lead to unintended
  behavior. For this reason, re-executing a Conn will trigger this error state.

  If you absolutely _must_ re-execute the Conn and cannot use a copy prior to execution,
  you can manually set the Conn's `:status` key to have a value of `:unexecuted`.
  This is unsupported, though.
  """

  @spec exception(nil) :: t
  def exception(_), do: %__MODULE__{}
end
