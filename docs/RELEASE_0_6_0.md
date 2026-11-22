# RoGoal v0.6.0 - Estruturas iniciais e exportação de projetos

## PT-BR

- Abra **Project context**, escreva o que deseja construir e copie o pedido para seu chat de IA. Cole ou abra o JSON da resposta em **Quick Apply** e confirme a criação no Studio.
- Os caminhos do JSON definem as pastas e os scripts. O importador aceita Script, LocalScript e ModuleScript e rejeita destinos já ocupados. Os pacotes TXT continuam disponíveis.
- Use **Export project .md** para salvar a hierarquia e as fontes disponíveis, inclusive dos scripts ainda não carregados no Explorer. O relatório identifica fontes indisponíveis. O limite é de 10.000 scripts ou 24 MiB de dados codificados.
- Instale o plugin **RoGoal.rbxmx** da mesma versão e refaça o pareamento para usar os novos recursos.

## English

Open **Project context** from the activity bar to compose a starter-project prompt. Copy the prompt into your AI chat, then paste its response into Quick Apply or use **Open file**. Quick Apply previews the resolved destinations and creates the folders and scripts after confirmation. The same workflow continues to accept existing TXT bundles.

```json
{"v":1,"s":[["ServerScriptService/Arena/Bootstrap","S","--!strict\nprint('Arena ready')"]]}
```

Each tuple contains a Studio path, a script class (`S` for Script, `L` for LocalScript, `M` for ModuleScript), and complete Luau source. Intermediate folders are inferred from the paths. Existing destinations are rejected. Install the matching Studio plugin and pair again before importing JSON.

Select **Export project .md** to save a Markdown file with a grouped hierarchy and the available source for each script in the Place, including scripts outside Explorer's loaded pages. Share the file with your AI chat manually. The export reports any sources Studio could not read and fails explicitly above 10,000 scripts or 24 MiB of encoded script data. It reads Studio editor sources. Sync any unsent RoGoal edits first if you want those edits reflected in the file.
