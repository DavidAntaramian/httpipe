defmodule HTTPipe.CurlHelpersTest do
  use ExUnit.Case

  alias HTTPipe.Request

  test "Can encode URL" do
    request =
      %Request{}
      |> Request.put_url("http://api.local/v1")

    curl_string = request |> Request.to_curl()
    assert curl_string == "curl -X GET http://api.local/v1"
  end

  test "Can encode HTTP method" do
    request =
      %Request{}
      |> Request.put_url("http://api.local/v1")
      |> Request.put_method(:post)

    curl_string = request |> Request.to_curl()
    assert curl_string == "curl -X POST http://api.local/v1"
  end

  test "Can encode headers" do
    request =
      %Request{}
      |> Request.put_url("http://api.local/v1")
      |> Request.put_header("Content-Type", "application/json")
      |> Request.put_header("Accept-Encoding", "gzip")

    curl_string = request |> Request.to_curl()
    assert curl_string == "curl -X GET http://api.local/v1 -H \"content-type: application/json\" -H \"accept-encoding: gzip\""
  end

  test "Can encode params into URL" do
    request =
      %Request{}
      |> Request.put_url("http://api.local/v1")
      |> Request.put_param(:q, "httpipe elixir")

    curl_string = request |> Request.to_curl()
    assert curl_string == "curl -X GET http://api.local/v1?q=httpipe+elixir"
  end

  test "Can encode body" do
    request =
      %Request{}
      |> Request.put_url("http://api.local/v1")
      |> Request.put_body("{}")

    curl_string = request |> Request.to_curl()
    assert curl_string == "curl -X GET http://api.local/v1 -d \"{}\""
  end

  test "Can encode form-based body" do
    req_body = {:form, [q: "elixir strings", limit: 10]}
    request =
      %Request{}
      |> Request.put_url("http://api.local/v1")
      |> Request.put_method(:post)
      |> Request.put_body(req_body)

    curl_string = request |> Request.to_curl()
    assert curl_string == "curl -X POST http://api.local/v1 -F \"limit=10\" -F \"q=elixir+strings\""
  end

  test "Can encode file-based body" do
    req_body = {:file, "/tmp/testfile"}
    request =
      %Request{}
      |> Request.put_url("http://api.local/v1")
      |> Request.put_method(:post)
      |> Request.put_body(req_body)

    curl_string = request |> Request.to_curl()
    assert curl_string == "curl -X POST http://api.local/v1 -d \"@/tmp/testfile\""
  end
end
