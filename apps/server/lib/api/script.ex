defmodule API.Script do
  require Logger

  def init(req0 = %{method: "POST"}, state) do
    permission = req0 |> API.get_permission()

    if permission != "admin" do
      req = :cowboy_req.reply(403, %{"content-type" => "text/plain"}, "", req0)
      {:ok, req, state}
    else
      {:ok, body, req1} = :cowboy_req.read_body(req0, %{length: 3 * 1024 * 1024})
      %{"name" => name_body, "script" => script} = body |> Poison.decode!()

      name_list =
        if is_list(name_body) do
          name_body
        else
          [name_body]
        end

      result_future_list =
        for name <- name_list do
          Task.async(fn -> {name, initate_script(name, script)} end)
        end

      result_formatter = fn res ->
        case res do
          {name, {:ok, id}} -> {name, %{success: true, id: id}}
          {name, {:error, reason}} -> {name, %{success: false, reason: reason}}
        end
      end

      result_list =
        for future <- result_future_list do
          Task.await(future) |> result_formatter.()
        end
        |> Map.new()

      req =
        :cowboy_req.reply(
          200,
          %{"content-type" => "application/json"},
          result_list |> Poison.encode!(),
          req1
        )

      {:ok, req, state}
    end
  rescue
    _ ->
      req =
        :cowboy_req.reply(
          400,
          %{"content-type" => "text/plain"},
          "",
          req0
        )

      {:ok, req, state}
  end

  def init(req0, state) do
    req =
      :cowboy_req.reply(
        405,
        %{"content-type" => "text/plain"},
        "",
        req0
      )

    {:ok, req, state}
  end

  def initate_script(name, script) do
    [{^name, %{"name" => ^name, "host" => host, "fingerprint" => fingerprint}}] =
      :dets.lookup(:clients, name)

    general_config = Application.get_env(:server, :general)
    network_config = Application.get_env(:server, :network)
    port = network_config |> Keyword.fetch!(:client_port)
    timeout = network_config |> Keyword.fetch!(:timeout)
    cert_path = general_config |> Keyword.fetch!(:cert_path)
    key_path = general_config |> Keyword.fetch!(:key_path)
    cacert_path = Application.app_dir(:server, "priv") |> Path.join("cacert.pem")

    opts = [
      :binary,
      active: false,
      packet: :line,
      verify_fun:
        {&:ssl_verify_fingerprint.verify_fun/3, [{:check_fingerprint, {:sha256, fingerprint}}]},
      verify: :verify_peer,
      certfile: cert_path,
      keyfile: key_path,
      cacertfile: cacert_path
    ]

    reason_to_string = fn reason ->
      if is_binary(reason) do
        reason
      else
        reason |> inspect
      end
    end

    command = ["command", script] |> pack()

    case :ssl.connect(host, port, opts, timeout) do
      {:ok, socket} ->
        :ssl.send(socket, command <> "\n")
        id = UUID.uuid4()

        {:ok, pid} =
          Task.Supervisor.start_child(TaskSupervisor, fn -> handle_script(socket, id, name) end)

        :ok = :ssl.controlling_process(socket, pid)
        {:ok, id}

      {:error, {:tls_alert, reason}} ->
        {:error, "tls_alert: " <> reason}

      {:error, reason} ->
        {:error, reason |> reason_to_string.()}
    end
  end

  def handle_script(socket, id, name) do
    :dets.insert(
      :script_results,
      {id, %{name: name, data: :not_available, timestamp: timestamp()}}
    )

    case :ssl.recv(socket, 0) do
      {:ok, data} ->
        :ssl.close(socket)
        [{^id, result_map}] = :dets.lookup(:script_results, id)
        updated_map = result_map |> Map.put(:data, data |> unpack())
        :dets.insert(:script_results, {id, updated_map})

      {:error, reason} ->
        Logger.error("script failed: #{name}-#{id}: " <> to_string(reason))
    end
  end

  defp pack(data) do
    data
    |> Msgpax.pack!()
    |> IO.iodata_to_binary()
    |> Base.encode64()
  end

  defp unpack(data) do
    data
    |> String.trim()
    |> Base.decode64!()
    |> Msgpax.unpack!()
  end

  defp timestamp() do
    DateTime.utc_now() |> DateTime.to_unix()
  end
end
