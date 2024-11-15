Application.ensure_all_started(:mimic)
Mimic.copy(Nx.Serving)
Mimic.copy(LangChain.Chains.LLMChain)
Mimic.copy(Req)

ExUnit.start()
