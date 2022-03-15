# FileDownloader
FileDownloader é um programa de teste de recursos para baixar vários arquivos. O programa permite incluir uma lista de arquivos para download, via interface ou um arquivo de texto correspondente, porém não é multithread. Os arquivos serão enfileirados e baixados um por um. Mudar para uma versão multithread é o ideal, mas isso levaria um pouco mais de tempo.

Este projeto começou com o uso do padrão de projeto Observer, mas rapidamente identifiquei que tal solução seria custosa para o propósito, é um típico excesso de engenharia porque em tese apenas um único observer seria o receptor neste projeto e o Observer não seria a solução mais adequada. Sendo mais adepto do princípio kiss, removi isto do projeto.

A engine de download deste projeto de testes igualmente não está utilizando interfaces e não se aplica ao princípio Open-Closed devido sua especificidade, não vejo o usuário (programador) ampliando a classe TDownloadFile via interface, mas sim no código. Por exemplo, digamos que queiramos alterar para incluir um método de teste de MD5 do arquivo baixado, para comparar com MD5 de verificação, se usamos interface para isso o código ficaria disperso. A solução seria, no caso deste exemplo, ou fazer esta verificação pós-download ou alterando-se a engine para nela sim executar a validação.

Este código está igualmente violando o princípio de inversão de dependência ali na conexão com o SQLite, já que se precisarmos mudar para outro banco, fatalmente precisaríamos modificar o data module.

O programa foi desenvolvido utilizando o Delphi 10.4.2 Community Edition. Não há dependência de nenhum componente extra ao bundle de instalação.

**Sobre o uso**

A interface apresenta uma lista de arquivos pré-preenchida, com subsídios sugeridos para o teste. Esta lista é carregada a partir de um arquivo texto. Novos itens podem ser incluídos ou removidos da lista.O tratamento dos links, que são digitados, é feita por simples sanitização utilizando uma regra de expressão regular, o conteúdo entretanto não é testado no tempo de inclusão do link (não faz-se acesso ao endpoint para validação - é inclusive desnecessário).

Procurei seguir os critérios de aceite propostos, entretanto devido ao design da tela e sua simplicidade, algumas coisas como textos de botões sugeridos foram adaptados. A interface não é, eventualmente, a mais amigável, entretanto procurei deixar o mais simples quanto possível.

A classe principal, TDownloadFile, possuí os seguintes métodos e propriedades principais, publicados:

- StartDownload - iniciar o download da fila de arquivos
- Abort - abortar a fila
- FilesToDownload - array de arquivos para serem baixados
- Position - posicionamento relativo (0-100) do andamento do arquivo atual que está sendo baixado
- IsDownloading - indica se a engine está baixando algum arquivo no momento
- DownloadFolder - setup da pasta de download (obs. no OnCreate do código)
- FileName - nome do arquivo que está sendo baixado no momento
- TotalFilesInQueue - total de arquivos na fila
- FileInQueue - indice do arquivo que está sendo baixado no momento
- Status - indicador de status do arquivo atual 

Além da engine, a View pode ser melhorada em demasia, no que diz respeito a sua arquitetura, como aplicar o uso de actions para manipular ações e textos dos botões dinâmicos, infelizmente faltou tempo para estes detalhes.

Foi habilitado o ReportMemoryLeaksOnShutdown pois o código apresenta leak de memória em algumas condições e igualmente não foi possível efetuar toda a depuração a tempo.

Vários outros detalhes da solução podem ser conferidos verificando o código. Os comentários está minimizados para apenas pontos de atenção.







