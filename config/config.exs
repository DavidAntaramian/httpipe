use Mix.Config

config :httpipe, adapter: HTTPipe.Adapters.Unimplemented

if File.exists?("config/#{Mix.env}.exs") do
  import_config "#{Mix.env}.exs"
end
