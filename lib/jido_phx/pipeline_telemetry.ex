defmodule JidoPhx.PipelineTelemetry do
  require Logger

  def handle_event([:jido, :agent, :signal, :start], _measurements, metadata, _config) do
    Logger.info(
      "[Jido] signal routing | agent=#{metadata[:agent_id]} type=#{metadata[:signal_type]}"
    )
  end

  def handle_event([:jido, :agent, :action, :start], _measurements, metadata, _config) do
    Logger.info("[Jido] action start | action=#{metadata[:action]} agent=#{metadata[:agent_id]}")
  end

  def handle_event([:jido, :agent, :action, :exception], _measurements, metadata, _config) do
    Logger.error(
      "[Jido] action failed | action=#{metadata[:action]} reason=#{inspect(metadata[:reason])}"
    )
  end

  def handle_event(_event, _measurements, _metadata, _config), do: :ok
end
