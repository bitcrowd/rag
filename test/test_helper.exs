Application.ensure_all_started(:mimic)
Mimic.copy(Nx.Serving)

ExUnit.start()
