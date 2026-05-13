 KISANGA-Q Web

Interface web em **R/Shiny** para o projeto **KISANGA-Q – Síntese Quilombola entre Biodiversidade, Clima e Saúde para o Bem Viver**.

O aplicativo organiza uma camada pública de navegação, catálogo e visualização para a biblioteca de dados do KISANGA-Q, um projeto de síntese científica que integra dados de biodiversidade, clima, saúde, condições sociais, regularização fundiária e conflitos territoriais em territórios quilombolas da Amazônia, Cerrado e Caatinga.

## Objetivo

O `kisangaQ_web` é a vitrine interativa do ecossistema KISANGA-Q. Seu objetivo é facilitar o acesso a informações sobre bases de dados, indicadores e produtos de síntese que possam apoiar pesquisa, gestão pública, devolutivas comunitárias e formulação de políticas intersetoriais em saúde, ambiente, igualdade racial e território.

## Funcionalidades atuais

- Página inicial com identidade visual do projeto, seção “Sobre” e carrossel de notícias.
- Catálogo de dados com filtros por tema, tipo de acesso e palavra-chave.
- Tabela interativa com metadados dos conjuntos de dados disponíveis.
- Painel de detalhes para cada base listada no catálogo.
- Prévia de arquivos de amostra quando disponíveis em `data/samples/`.
- Página de dashboard reservada para futuras análises e visualizações.

## Estrutura do repositório

```text
kisangaQ_web/
├── README.md
├── global.R
├── ui.R
├── server.R
├── R/
│   ├── mod_home.R
│   ├── mod_catalog.R
│   └── mod_dashboard.R
├── data/
│   ├── datasets.csv
│   ├── news.csv
│   └── samples/
└── www/
    ├── custom.css
    ├── logo.png
    └── giphy.gif
```


## Relação com o repositório `KisangaQ`

Este repositório contém a camada web da plataforma. O repositório [`KisangaQ`](https://github.com/rodriguesmsb/KisangaQ) concentra scripts de análise, preparação e geração de amostras de dados utilizadas pelo aplicativo.

Fluxo esperado:

```text
KisangaQ
  └── scripts de preparação, harmonização e amostragem
        ↓
kisangaQ_web/data/samples
  └── arquivos CSV de prévia usados pelo catálogo
```

## Status

Em desenvolvimento.

## Licença


## Contato

Moreno Rodrigues  
GitHub: [@rodriguesmsb](https://github.com/rodriguesmsb)

