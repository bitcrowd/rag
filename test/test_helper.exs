Application.ensure_all_started(:mimic)
Mimic.copy(Nx.Serving)
Mimic.copy(Req)

ExUnit.start()
