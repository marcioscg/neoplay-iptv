/* ===== Ícones (stroke 24x24) ===== */
const P = {
  search:'<circle cx="10.5" cy="10.5" r="6.5"/><path d="M15.5 15.5L21 21"/>',
  gear:'<circle cx="12" cy="12" r="3.3"/><circle cx="12" cy="12" r="7.7" stroke-dasharray="3.4 2.3"/>',
  dots:'<circle cx="12" cy="5" r="1.5" fill="currentColor" stroke="none"/><circle cx="12" cy="12" r="1.5" fill="currentColor" stroke="none"/><circle cx="12" cy="19" r="1.5" fill="currentColor" stroke="none"/>',
  chev:'<path d="M9.5 5l7 7-7 7"/>',
  back:'<path d="M20 12H4M10 6l-6 6 6 6"/>',
  close:'<path d="M6 6l12 12M18 6L6 18"/>',
  cast:'<path d="M4 6.5h16v11h-6.5"/><path d="M4 11.5a7 7 0 017 7M4 15.5a3 3 0 013 3"/><circle cx="4.3" cy="18.9" r="1" fill="currentColor" stroke="none"/>',
  menu:'<path d="M4 7h16M4 12h16M4 17h16"/>',
  heart:'<path d="M12 20s-7-4.4-7-9.4A3.85 3.85 0 0112 8.1a3.85 3.85 0 017 2.5c0 5-7 9.4-7 9.4z"/>',
  info:'<circle cx="12" cy="12" r="9"/><path d="M12 11v6M12 7.4v.7"/>',
  pause:'<path d="M9 5v14M15 5v14" stroke-width="2.6"/>',
  play:'<path d="M8 5l12 7-12 7z" fill="currentColor" stroke="none"/>',
  fs:'<path d="M4 9V4h5M20 9V4h-5M4 15v5h5M20 15v5h-5"/>',
  sub:'<rect x="3" y="5" width="18" height="14" rx="2.5"/><path d="M6.5 14h4.5M13.5 14h4"/>',
  audio:'<path d="M4 15V9h3l5-4v14l-5-4H4z"/><path d="M16 9.6a4 4 0 010 4.8"/>',
  lock:'<rect x="5" y="10.5" width="14" height="9.5" rx="2.2"/><path d="M8.5 10.5V8a3.5 3.5 0 017 0v2.5"/>',
  palette:'<circle cx="12" cy="12" r="9"/><circle cx="9" cy="9.5" r="1.3" fill="currentColor" stroke="none"/><circle cx="15" cy="9.5" r="1.3" fill="currentColor" stroke="none"/><circle cx="9.6" cy="15" r="1.3" fill="currentColor" stroke="none"/>',
  globe:'<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c3 3.6 3 14.4 0 18M12 3c-3 3.6-3 14.4 0 18"/>',
  help:'<circle cx="12" cy="12" r="9"/><path d="M9.6 9.6a2.4 2.4 0 114.8 0c0 1.7-2.4 1.9-2.4 3.9M12 17.1v.5"/>',
  cloud:'<path d="M6.6 18.5a3.6 3.6 0 01.3-7.2A5.2 5.2 0 0117 9.9a4 4 0 01.4 8.6H6.6z"/>',
  trash:'<path d="M4 7h16M9.5 7V4.8h5V7M6.3 7l1 13h9.4l1-13"/>',
  refresh:'<path d="M20 12a8 8 0 11-2.8-6.1M20 4.2v5h-5"/>',
  tv:'<rect x="3" y="4.5" width="18" height="12.5" rx="2.2"/><path d="M8.5 21h7M12 17v4"/>',
  film:'<rect x="3" y="4" width="18" height="16" rx="2.2"/><path d="M3 9.3h18M3 14.7h18M8 4v16M16 4v16"/>',
  layers:'<path d="M4 8l8-4 8 4-8 4-8-4z"/><path d="M4 12.2l8 4 8-4M4 16.2l8 4 8-4"/>',
  grid:'<rect x="4" y="4" width="7" height="7" rx="1.4"/><rect x="13" y="4" width="7" height="7" rx="1.4"/><rect x="4" y="13" width="7" height="7" rx="1.4"/><rect x="13" y="13" width="7" height="7" rx="1.4"/>',
  clock:'<circle cx="12" cy="12" r="9"/><path d="M12 7.2V12l3.6 2"/>',
  crown:'<path d="M4 18.2h16L18.3 8l-4 3.6L12 5.2 9.7 11.6 5.7 8z"/>',
  key:'<circle cx="8" cy="12" r="3.8"/><path d="M11.8 12H21M18 12v3.2"/>',
  shield:'<path d="M12 3.2l7 2.9v5.8c0 4.9-3.4 7.9-7 9-3.6-1.1-7-4.1-7-9V6.1z"/>',
  plus:'<path d="M12 5v14M5 12h14"/>',
  check:'<path d="M5 12.8l4.3 4.2L19 7.2"/>',
  folder:'<path d="M3 6.8h6l2 2.2h10V19H3z"/>',
  link:'<path d="M9.3 14.7l5.4-5.4M8.4 8.2H6.6a3.9 3.9 0 000 7.8h1.8M15.6 8.2h1.8a3.9 3.9 0 010 7.8h-1.8"/>',
  user:'<circle cx="12" cy="8" r="3.6"/><path d="M5 20c1.5-3.5 4-5 7-5s5.5 1.5 7 5"/>',
  dl:'<path d="M12 4v11M7.4 10.8L12 15.4l4.6-4.6M5 20h14"/>',
  pip:'<rect x="3" y="5" width="18" height="14" rx="2.2"/><rect x="11.8" y="11" width="7" height="6" rx="1.2"/>',
  star:'<path d="M12 4l2.5 5.2 5.5.8-4 3.9 1 5.6-5-2.8-5 2.8 1-5.6-4-3.9 5.5-.8z"/>',
  wifi:'<path d="M2.5 8.5a14 14 0 0119 0M6 12.4a9 9 0 0112 0M9.6 16.2a4.2 4.2 0 014.8 0"/><circle cx="12" cy="19.4" r="1" fill="currentColor" stroke="none"/>',
  eye:'<path d="M2.5 12S6 6.5 12 6.5 21.5 12 21.5 12 18 17.5 12 17.5 2.5 12 2.5 12z"/><circle cx="12" cy="12" r="2.8"/>'
};
const ic = (n, cls='') => `<svg class="ic ${cls}" viewBox="0 0 24 24">${P[n]||''}</svg>`;
const icOff = n => `<svg class="ic off" viewBox="0 0 24 24">${P[n]||''}<path d="M4 20L20 4" stroke-width="1.6"/></svg>`;

/* ===== Blocos reutilizáveis ===== */
const sbar = (t='22:51') => `<div class="sbar"><span>${t}</span><span class="sbicons">${ic('wifi')}<i class="bat"></i></span></div>`;
const nbar = () => `<div class="nbar"><span class="nb1"></span><span class="nb2"></span><span class="nb3"></span></div>`;
const logo = () => `<div class="logo">NEO<span>PLAY</span><i class="lg"></i></div>`;
const appbar = (title, right='', left='back') => `<div class="appbar">${left?`<button class="ib">${ic(left)}</button>`:''}<div class="abt">${title}</div><div class="abr">${right}</div></div>`;
const tabs = (items, active) => `<div class="tabs">${items.map((t,i)=>`<div class="tab ${i===active?'on':''}">${t}</div>`).join('')}</div>`;
const row = (label, meta='', o={}) => `<div class="row ${o.cls||''}">${o.icon?`<span class="ri">${ic(o.icon)}</span>`:''}<span class="rl">${label}${o.sub?`<em>${o.sub}</em>`:''}</span>${meta?`<span class="rm">${meta}</span>`:''}${o.noChev?'':`<span class="rc">${ic('chev')}</span>`}</div>`;
const sw = (label, on=true, sub='') => `<div class="row"><span class="rl">${label}${sub?`<em>${sub}</em>`:''}</span><span class="switch ${on?'on':''}"></span></div>`;
const sect = t => `<div class="sect">${t}</div>`;
const btn = (t, cls='') => `<button class="btn ${cls}">${t}</button>`;
const poster = (t, sub, g=1) => `<div class="poster g${g}"><div class="pg"></div><b>${t}</b>${sub?`<i>${sub}</i>`:''}</div>`;
const chan = (n, name, prog, pct=0, fav=false) => `<div class="chan"><div class="clogo g${(n%6)+1}">${name.slice(0,2).toUpperCase()}</div><div class="cinf"><b>${n}. ${name}</b><span>${prog}</span><div class="bar"><i style="width:${pct}%"></i></div></div>${fav?`<span class="favi">${ic('heart','fill')}</span>`:''}</div>`;

/* ===== Telas ===== */
const S = [];
const add = (title, note, body, cls='') => S.push({title, note, body, cls});

/* 1. Splash */
add('01 · Splash', 'Abre carregando a lista salva',
`${sbar()}<div class="splash">${logo()}<div class="sload"><i></i></div><span class="smut">Carregando sua lista…</span><span class="sver">v1.0.0</span></div>${nbar()}`);

/* 2. Onboarding / adicionar lista */
add('02 · Adicionar lista', 'Xtream Codes · M3U · arquivo',
`${sbar()}${appbar('Adicionar lista','',null)}
<div class="pad">
  <div class="hero"><b>Como você quer entrar?</b><span>Sua lista é sua. O app é só o player.</span></div>
  ${row('Xtream Codes','', {icon:'user', sub:'Host + usuário + senha'})}
  ${row('URL M3U / M3U8','', {icon:'link', sub:'Link direto da lista'})}
  ${row('Arquivo local','', {icon:'folder', sub:'Selecionar .m3u do aparelho'})}
  ${row('Código do dispositivo','', {icon:'key', sub:'Cadastrar pelo painel web'})}
  <div class="devkey"><span>Device Key</span><b>7F42 · 9AB1 · C3D8</b><i>MAC 1A:2B:3C:4D:5E:6F</i></div>
  <div class="disc">${ic('shield')}<span>O aplicativo não fornece nem hospeda conteúdo.</span></div>
</div>${nbar()}`);

/* 3. Form Xtream */
add('03 · Login Xtream', 'Validação + teste de conexão',
`${sbar()}${appbar('Xtream Codes')}
<div class="pad">
  <label class="fl">Nome da lista</label><div class="inp">Minha Lista</div>
  <label class="fl">Servidor (host)</label><div class="inp">http://servidor.com:8080</div>
  <label class="fl">Usuário</label><div class="inp">marcio_2026</div>
  <label class="fl">Senha</label><div class="inp">••••••••••</div>
  <label class="fl">EPG (XMLTV) — opcional</label><div class="inp mut">auto (xmltv.php)</div>
  <div class="row2">${sw('Salvar credenciais cifradas',true)}</div>
  ${btn('Testar e conectar','pri')}
  <div class="okline">${ic('check','ok')}<span>Conta ativa · expira 12/12/2026 · 2 conexões</span></div>
</div>${nbar()}`);

/* 4. Gerenciar playlists */
add('04 · Listas de reprodução', 'Multi-lista + multiperfil',
`${sbar()}${appbar('Listas de reprodução', `<button class="ib">${ic('plus')}</button>`, 'close')}
<div class="pad0">
  ${row('Minha Lista','ATIVA',{icon:'tv', sub:'Xtream · 1517 canais · 4h atrás', cls:'on'})}
  ${row('Lista Backup','',{icon:'tv', sub:'M3U URL · 980 canais · ontem'})}
  ${row('Casa da praia','',{icon:'tv', sub:'Arquivo local · 412 canais'})}
  ${sect('PERFIS')}
  ${row('Marcio','',{icon:'user', sub:'Sem restrição'})}
  ${row('Filhos','',{icon:'user', sub:'Controle parental ativo'})}
  ${row('Adicionar perfil','',{icon:'plus'})}
</div>${nbar()}`);

/* 5. Home canais (categorias) */
add('05 · Home · Canais', 'Categorias da lista ativa',
`${sbar()}<div class="appbar main">${logo()}<div class="abr">${ic('search')}${ic('gear')}${ic('dots')}</div></div>
${tabs(['Canais','Filmes','Séries','Guia'],0)}
<div class="pad0">
  ${row('Todos os canais','1517',{icon:'grid'})}
  ${row('Assistido recentemente','',{icon:'clock'})}
  ${row('Favoritos','38',{icon:'heart', cls:'acc'})}
  ${row('Jogos do dia','7',{icon:'star', cls:'acc'})}
  ${row('Globos principais','12')}
  ${row('Filmes &amp; Séries HD','214')}
  ${row('Esportes','96')}
  ${row('Documentários','58')}
  ${row('Infantil','73')}
  ${row('Notícias','41')}
  ${row('Rádios','14')}
</div>${nbar()}`);

/* 6. Lista de canais */
add('06 · Canais da categoria', 'EPG “agora” + progresso',
`${sbar()}${appbar('Esportes', `<button class="ib">${ic('search')}</button><button class="ib">${ic('grid')}</button>`)}
<div class="pad0">
  ${chan(1,'Premiere 1','Athletico x Coritiba',62,true)}
  ${chan(2,'SporTV','Seleção SporTV',35)}
  ${chan(3,'ESPN','NBA Hoje',80)}
  ${chan(4,'TNT Sports','Libertadores ao vivo',18,true)}
  ${chan(5,'Band Sports','Boletim Esportivo',44)}
  ${chan(6,'Combate','UFC Fight Night',70)}
  ${chan(7,'Cazé TV','Pós-jogo',12)}
</div>${nbar()}`);

/* 7. Player ao vivo */
add('07 · Player ao vivo', 'Controles + EPG do canal',
`${sbar('22:52')}${appbar('Globo São Paulo HD', `<button class="ib">${ic('cast')}</button><button class="ib">${ic('menu')}</button>`)}
<div class="video"><div class="vgrad"></div><span class="live">AO VIVO</span><span class="vq">1080p · H.264</span></div>
<div class="pctrl">
  <div class="pline"><b>Fantástico</b><span>00:08:01</span></div>
  <div class="ptime"><span>22:00</span><div class="bar big"><i style="width:57%"></i></div><span>23:00</span></div>
  <div class="picons">${ic('pause')}${ic('info')}${ic('heart')}${ic('sub')}${ic('audio')}${ic('pip')}${ic('fs')}</div>
</div>
<div class="pad0">
  ${sect('AGORA E DEPOIS')}
  <div class="epgi on"><span>22:00</span><b>Fantástico</b></div>
  <div class="epgi"><span>23:00</span><b>Domingo Maior</b></div>
  <div class="epgi"><span>01:10</span><b>Corujão</b></div>
</div>${nbar()}`);

/* 8. Guia EPG */
add('08 · Guia de programação', 'Grade horizontal (timeline)',
`${sbar()}${appbar('Guia do programa', `<button class="ib">${ic('clock')}</button>`)}
<div class="epgbar"><span class="on">Hoje</span><span>Amanhã</span><span>Ter</span><span>Qua</span></div>
<div class="epgh"><span>22:00</span><span>22:30</span><span>23:00</span><span>23:30</span></div>
<div class="epggrid">
  ${[['Globo SP','Fantástico','Domingo Maior'],['SBT','Programa Silvio','Cine Espetacular'],['Record','Domingo Espetacular','Câmera'],['Band','Show do Esporte','Jornal'],['SporTV','Seleção','Troca de Passes'],['Premiere','Athletico x CAP','Pós-jogo'],['ESPN','NBA Hoje','SportsCenter']].map(r=>
  `<div class="er"><div class="ech">${r[0]}</div><div class="ecs"><div class="ep now" style="flex:2.2">${r[1]}<i></i></div><div class="ep" style="flex:2.8">${r[2]}</div><div class="ep" style="flex:1.4">Madrugada</div></div></div>`).join('')}
</div>
<div class="nowline"></div>${nbar()}`);

/* 9. Filmes grid */
add('09 · Filmes (VOD)', 'Capas via TMDB + filtros',
`${sbar()}<div class="appbar main">${logo()}<div class="abr">${ic('search')}${ic('gear')}${ic('dots')}</div></div>
${tabs(['Canais','Filmes','Séries','Guia'],1)}
<div class="chips"><span class="on">Todos</span><span>Ação</span><span>Comédia</span><span>Nacional</span><span>4K</span></div>
<div class="grid3">
  ${poster('Duna 2','2024',1)}${poster('Deadpool','2024',2)}${poster('Divertida Mente','2024',3)}
  ${poster('Oppenheimer','2023',4)}${poster('Coringa','2019',5)}${poster('Ainda Estou Aqui','2024',6)}
  ${poster('Vingadores','2019',2)}${poster('Matrix','1999',3)}${poster('Tropa de Elite','2007',1)}
</div>${nbar()}`);

/* 10. Detalhe filme */
add('10 · Detalhe do filme', 'Sinopse, elenco, trailer',
`${sbar()}<div class="backdrop"><div class="bgrad"></div><button class="ib fab">${ic('back')}</button><div class="bdinfo"><b>Duna: Parte 2</b><span>2024 · 2h46 · Ficção · ${'★'} 8.5</span></div></div>
<div class="pad">
  <div class="btnrow">${btn('▶  Assistir','pri')}${btn(ic('heart'),'ico')}${btn(ic('dl'),'ico')}${btn(ic('cast'),'ico')}</div>
  <p class="syn">Paul Atreides se une aos Fremen para vingar sua família e impedir um futuro terrível que só ele consegue prever.</p>
  ${row('Áudio e legendas','PT-BR · Leg', {noChev:false})}
  ${sect('RELACIONADOS')}
  <div class="grid3 sm">${poster('Duna','2021',4)}${poster('Blade R.','2049',5)}${poster('Arrival','2016',6)}</div>
</div>${nbar()}`);

/* 11. Séries / episódios */
add('11 · Série · episódios', 'Temporadas + continuar de onde parou',
`${sbar()}<div class="backdrop sm2"><div class="bgrad"></div><button class="ib fab">${ic('back')}</button><div class="bdinfo"><b>Round 6</b><span>3 temporadas · 22 episódios</span></div></div>
<div class="chips"><span class="on">T1</span><span>T2</span><span>T3</span></div>
<div class="pad0">
  <div class="epi"><div class="ethumb g3"></div><div class="einf"><b>1. Luz vermelha, luz verde</b><span>59 min · assistido</span><div class="bar"><i style="width:100%"></i></div></div></div>
  <div class="epi"><div class="ethumb g4"></div><div class="einf"><b>2. Inferno</b><span>62 min · faltam 24 min</span><div class="bar"><i style="width:61%"></i></div></div></div>
  <div class="epi"><div class="ethumb g5"></div><div class="einf"><b>3. O homem com o guarda-chuva</b><span>55 min</span></div></div>
  <div class="epi"><div class="ethumb g6"></div><div class="einf"><b>4. Time de dois</b><span>54 min</span></div></div>
</div>${nbar()}`);

/* 12. Busca global */
add('12 · Busca global', 'Canais, filmes, séries e EPG',
`${sbar()}<div class="appbar"><button class="ib">${ic('back')}</button><div class="sinp">${ic('search')}<span>globo</span><i>${ic('close')}</i></div></div>
${tabs(['Tudo','Canais','Filmes','Séries'],0)}
<div class="pad0">
  ${sect('CANAIS · 14')}
  ${chan(1,'Globo SP HD','Fantástico',57)}
  ${chan(2,'Globo RJ HD','Fantástico',57)}
  ${sect('FILMES · 3')}
  <div class="grid3 sm">${poster('Globo Repórter','Doc',2)}${poster('Ainda Estou','2024',3)}${poster('Cine Globo','Coleção',1)}</div>
  ${sect('NO GUIA · 6')}
  <div class="epgi"><span>23:00</span><b>Domingo Maior — Globo SP</b></div>
</div>${nbar()}`);

/* 13. Favoritos / recentes */
add('13 · Favoritos e recentes', 'Reordenação por arraste',
`${sbar()}${appbar('Favoritos', `<button class="ib">${ic('menu')}</button>`)}
<div class="pad0">
  ${sect('CONTINUAR ASSISTINDO')}
  <div class="rail">${poster('Round 6','T1E2 · 61%',3)}${poster('Duna 2','1h12 rest.',1)}${poster('Coringa','34%',5)}</div>
  ${sect('CANAIS FAVORITOS')}
  ${chan(1,'Premiere 1','Athletico x Coritiba',62,true)}
  ${chan(2,'Globo SP','Fantástico',57,true)}
  ${chan(3,'Combate','UFC Fight Night',70,true)}
  ${chan(4,'Cazé TV','Pós-jogo',12,true)}
</div>${nbar()}`);

/* 14. Configurações */
add('14 · Configurações', 'Espelha o padrão do mercado',
`${sbar()}${appbar('Configurações','','close')}
<div class="pad0">
  ${row('Obtenha a versão Premium','',{icon:'crown', cls:'acc'})}
  ${row('Listas de reprodução','3')}
  ${row('Guia do programa (EPG)','')}
  ${row('Atualizar lista de reprodução','',{noChev:true})}
  ${row('Forçar atualização do EPG','',{noChev:true})}
  ${row('Configurações do player','')}
  ${row('Restauração e backup','')}
  ${row('Controle parental','')}
  ${row('Exclusão de dados','',{noChev:true})}
  ${row('Tema de cores','Escuro')}
  ${row('Língua','Português (BR)')}
  ${row('Ajuda e suporte','')}
  <div class="foot">NEOPLAY · versão 1.0.0 (build 112)</div>
</div>${nbar()}`);

/* 15. Config player */
add('15 · Configurações do player', 'Decoder, buffer, aspecto',
`${sbar()}${appbar('Player')}
<div class="pad0">
  ${sect('REPRODUÇÃO')}
  ${row('Player padrão','ExoPlayer')}
  ${row('Decodificação','Hardware +')}
  ${row('Buffer','2500 ms')}
  ${row('Proporção de tela','Ajustar')}
  ${sw('Reconectar automaticamente',true,'Tenta 3x em caso de queda')}
  ${sw('Picture-in-Picture',true)}
  ${sw('Continuar de onde parou',true)}
  ${sect('LEGENDAS')}
  ${row('Tamanho da legenda','Médio')}
  ${row('Cor / fundo','Branco · sombra')}
  ${sect('REDE')}
  ${row('User-Agent','Padrão da lista')}
  ${sw('Usar apenas Wi-Fi para VOD',false)}
</div>${nbar()}`);

/* 16. Backup */
add('16 · Backup e restauração', 'Local e nuvem por Device Key',
`${sbar()}${appbar('Restauração e backup')}
<div class="pad">
  <div class="hero sm"><b>Último backup</b><span>Hoje, 21:40 · 3 listas · 38 favoritos</span></div>
  ${row('Fazer backup na nuvem','',{icon:'cloud'})}
  ${row('Exportar arquivo (.neo)','',{icon:'dl'})}
  ${row('Restaurar de arquivo','',{icon:'folder'})}
  ${row('Restaurar da nuvem','',{icon:'refresh'})}
  ${sect('O QUE ENTRA NO BACKUP')}
  ${sw('Listas e credenciais',true)}
  ${sw('Favoritos e histórico',true)}
  ${sw('Preferências do player',true)}
  <div class="disc">${ic('lock')}<span>Credenciais cifradas com AES-256 no dispositivo.</span></div>
</div>${nbar()}`);

/* 17. Tema */
add('17 · Tema de cores', 'Escuro, AMOLED, claro, acento',
`${sbar()}${appbar('Tema de cores')}
<div class="pad">
  <div class="themes"><div class="th on"><i class="t1"></i><span>Escuro</span></div><div class="th"><i class="t2"></i><span>AMOLED</span></div><div class="th"><i class="t3"></i><span>Claro</span></div></div>
  ${sect('COR DE DESTAQUE')}
  <div class="swatches"><i class="s1 on"></i><i class="s2"></i><i class="s3"></i><i class="s4"></i><i class="s5"></i><i class="s6"></i></div>
  ${sect('LISTAS')}
  ${row('Densidade','Confortável')}
  ${sw('Mostrar logos dos canais',true)}
  ${sw('Mostrar número do canal',true)}
  ${sw('Fonte maior na TV',false)}
</div>${nbar()}`);

/* 18. Controle parental */
add('18 · Controle parental', 'PIN + bloqueio de categorias',
`${sbar()}${appbar('Controle parental')}
<div class="pad">
  <div class="pin"><i></i><i></i><i></i><i class="e"></i><span>Digite o PIN de 4 dígitos</span></div>
  ${sect('BLOQUEIOS')}
  ${sw('Bloquear categoria Adulto',true)}
  ${sw('Pedir PIN ao abrir o app',false)}
  ${sw('Bloquear configurações',true)}
  ${row('Categorias bloqueadas','4')}
  ${row('Alterar PIN','')}
  <div class="disc">${ic('shield')}<span>Recuperação de PIN pelo e-mail cadastrado.</span></div>
</div>${nbar()}`);

/* 19. Premium */
add('19 · Premium / ativação', 'Chave vitalícia ou assinatura',
`${sbar()}${appbar('Versão Premium','','close')}
<div class="pad">
  <div class="hero pre">${ic('crown','big')}<b>NEOPLAY Premium</b><span>Sem anúncios · listas ilimitadas · backup na nuvem · multi-tela</span></div>
  <div class="plans">
    <div class="plan"><b>Mensal</b><span>R$ 9,90</span><i>por mês</i></div>
    <div class="plan on"><em>MAIS VENDIDO</em><b>Vitalício</b><span>R$ 79,90</span><i>1 dispositivo</i></div>
  </div>
  ${btn('Ativar agora','pri')}
  ${row('Já tenho uma chave','',{icon:'key'})}
  ${row('Restaurar compra','',{icon:'refresh'})}
  <div class="foot">Device Key 7F42-9AB1-C3D8</div>
</div>${nbar()}`);

/* 20. Erro / diagnóstico */
add('20 · Erro e diagnóstico', 'Estados de falha bem tratados',
`${sbar()}${appbar('Diagnóstico')}
<div class="pad">
  <div class="errbox">${ic('info','big')}<b>Não foi possível abrir o canal</b><span>Código 403 · limite de conexões da sua lista atingido</span></div>
  ${btn('Tentar novamente','pri')}${btn('Trocar de fonte','')}
  ${sect('TESTES')}
  <div class="okline">${ic('check','ok')}<span>Internet — 48 Mbps</span></div>
  <div class="okline">${ic('check','ok')}<span>Servidor da lista respondeu em 210 ms</span></div>
  <div class="okline bad">${ic('close','bad')}<span>Stream recusado (403)</span></div>
  <div class="okline">${ic('check','ok')}<span>EPG atualizado há 12 min</span></div>
  ${row('Enviar log ao suporte','',{icon:'dl'})}
</div>${nbar()}`);

/* ===== TVs ===== */
const TV = [];
TV.push({title:'21 · Android TV · navegação por D-pad', body:`
<div class="tvui">
  <div class="tvside">${logo()}<div class="tvnav"><span class="on">${ic('tv')}Canais</span><span>${ic('film')}Filmes</span><span>${ic('layers')}Séries</span><span>${ic('grid')}Guia</span><span>${ic('search')}Busca</span><span>${ic('gear')}Ajustes</span></div></div>
  <div class="tvmain">
    <div class="tvhero"><div class="tvhg"></div><div class="tvhi"><b>Premiere 1 · AO VIVO</b><span>Athletico x Coritiba — 2º tempo · 22:00 às 23:50</span><div class="btnrow">${btn('▶  Assistir','pri')}${btn('+ Favoritos','')}</div></div></div>
    <div class="tvrail"><span class="rt">Continuar assistindo</span><div class="rail">${poster('Round 6','T1E2',3)}${poster('Duna 2','1h12',1)}${poster('Coringa','34%',5)}${poster('Oppen.','2023',4)}${poster('Matrix','1999',6)}</div></div>
    <div class="tvrail"><span class="rt">Canais favoritos</span><div class="rail sm">${['Globo','SporTV','ESPN','TNT','Combate','Cazé'].map((c,i)=>`<div class="tvch g${i+1}">${c}</div>`).join('')}</div></div>
  </div>
</div>`});
TV.push({title:'22 · Android TV · player + mini-guia', body:`
<div class="tvui play">
  <div class="tvvideo"><div class="tvvg"></div><span class="live">AO VIVO</span>
    <div class="tvosd"><div class="pline"><b>Premiere 1 · Athletico x Coritiba</b><span>2º tempo · 22:00–23:50</span></div><div class="ptime"><span>22:00</span><div class="bar big"><i style="width:66%"></i></div><span>23:50</span></div><div class="picons">${ic('pause')}${ic('info')}${ic('heart')}${ic('sub')}${ic('audio')}${ic('fs')}</div></div>
    <div class="tvmini"><span class="rt">Zapear</span>${['Globo SP · Fantástico','SporTV · Seleção','ESPN · NBA Hoje','TNT · Libertadores','Combate · UFC'].map((c,i)=>`<div class="mch ${i===1?'on':''}">${c}</div>`).join('')}</div>
  </div>
</div>`});

/* ===== Render ===== */
document.getElementById('phones').innerHTML = S.map(s=>`
<figure class="pw"><div class="phone ${s.cls}">${s.body}</div><figcaption><b>${s.title}</b><span>${s.note}</span></figcaption></figure>`).join('');
document.getElementById('tvs').innerHTML = TV.map(t=>`
<figure class="tw"><div class="tv">${t.body}</div><figcaption><b>${t.title}</b></figcaption></figure>`).join('');
