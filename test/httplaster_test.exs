defmodule HTTPlasterTest do
  use ExUnit.Case, async: false

  setup do
    default_adapter = Application.get_env(:httplaster, :adapter)

    Application.put_env(:httplaster, :adapter, HTTPlaster.Adapters.HTTPC)

    on_exit(fn ->
      Application.put_env(:httplaster, :adapter, default_adapter)
    end)

    :ok
  end

  describe "get/3" do
    test "Can GET from server" do
      request_size = :rand.uniform(200)
      {:ok, conn} = HTTPlaster.get("https://httpbin.org/bytes/#{request_size}")

      assert :erlang.size(conn.response.body) == request_size
    end

    test "sends headers to server" do
      headers = %{"Accept" => "application/json"}
      {:ok, conn} = HTTPlaster.get("https://httpbin.org/get", headers)

      {:ok, decoded_body} = Poison.decode(conn.response.body)

      accept_header = get_in(decoded_body, ["headers", "Accept"])

      assert accept_header == headers["Accept"]
    end

  end
end
