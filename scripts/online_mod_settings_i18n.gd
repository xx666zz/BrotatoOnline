extends Reference

const FALLBACK_LOCALE = "en"

const MESSAGES = {
	"en": {
		"BROTATO_ONLINE_MENU_SETTINGS": "Online Settings",
		"BROTATO_ONLINE_SETTINGS_TITLE": "Brotato Online Settings",
		"BROTATO_ONLINE_LOCAL_CHARACTER_OUTLINE": "Outline local character",
		"BROTATO_ONLINE_LOCAL_CHARACTER_OUTLINE_DESC": "In online battles, add a character outline only to the player controlled on this machine. This does not change the vanilla circle under players.",
		"BROTATO_ONLINE_AUTO_JOIN_HOST_PLAYER": "Auto-add host as Player 1",
		"BROTATO_ONLINE_AUTO_JOIN_HOST_PLAYER_DESC": "Default: on. If you turn this off, the host must first join and lock Player 1 with the intended keyboard/controller on the character selection screen, then other players may join. If Player 2 joins before Player 1 is ready, character slots or focus may desync.",
	},
	"zh": {
		"BROTATO_ONLINE_MENU_SETTINGS": "联机设置",
		"BROTATO_ONLINE_SETTINGS_TITLE": "土豆兄弟联机设置",
		"BROTATO_ONLINE_LOCAL_CHARACTER_OUTLINE": "开启本机角色描边",
		"BROTATO_ONLINE_LOCAL_CHARACTER_OUTLINE_DESC": "联机战斗中，只给本机正在控制的角色添加人物描边。不改原版脚下圆圈。",
		"BROTATO_ONLINE_AUTO_JOIN_HOST_PLAYER": "自动加入房主 1 号位",
		"BROTATO_ONLINE_AUTO_JOIN_HOST_PLAYER_DESC": "默认开启。关闭后，房主必须先在角色选择页用要使用的键盘/手柄加入并确定 1 号位输入设备，其他玩家才能进入。否则 2 号位先进入可能导致角色槽或焦点不同步。",
	},
	"zh_TW": {
		"BROTATO_ONLINE_MENU_SETTINGS": "連線設定",
		"BROTATO_ONLINE_SETTINGS_TITLE": "土豆兄弟連線設定",
		"BROTATO_ONLINE_LOCAL_CHARACTER_OUTLINE": "開啟本機角色描邊",
		"BROTATO_ONLINE_LOCAL_CHARACTER_OUTLINE_DESC": "連線戰鬥中，只給本機正在控制的角色添加人物描邊。不改原版腳下圓圈。",
		"BROTATO_ONLINE_AUTO_JOIN_HOST_PLAYER": "自動加入房主 1 號位",
		"BROTATO_ONLINE_AUTO_JOIN_HOST_PLAYER_DESC": "預設開啟。關閉後，房主必須先在角色選擇頁用要使用的鍵盤/手把加入並確定 1 號位輸入裝置，其他玩家才能進入。否則 2 號位先進入可能導致角色槽或焦點不同步。",
	},
	"ja": {
		"BROTATO_ONLINE_MENU_SETTINGS": "オンライン設定",
		"BROTATO_ONLINE_SETTINGS_TITLE": "Brotato Online 設定",
		"BROTATO_ONLINE_LOCAL_CHARACTER_OUTLINE": "ローカルキャラのアウトライン",
		"BROTATO_ONLINE_LOCAL_CHARACTER_OUTLINE_DESC": "オンライン戦闘中、この端末で操作しているキャラクターだけにアウトラインを追加します。標準の足元の円は変更しません。",
		"BROTATO_ONLINE_AUTO_JOIN_HOST_PLAYER": "ホストをプレイヤー1に自動追加",
		"BROTATO_ONLINE_AUTO_JOIN_HOST_PLAYER_DESC": "既定ではオンです。オフにする場合、他のプレイヤーが参加する前に、ホストがキャラクター選択画面で使用するキーボード/コントローラーを使ってプレイヤー1として参加し、入力デバイスを確定してください。プレイヤー2が先に参加すると、スロットやフォーカスがずれる場合があります。",
	},
	"ko": {
		"BROTATO_ONLINE_MENU_SETTINGS": "온라인 설정",
		"BROTATO_ONLINE_SETTINGS_TITLE": "Brotato Online 설정",
		"BROTATO_ONLINE_LOCAL_CHARACTER_OUTLINE": "내 캐릭터 외곽선 표시",
		"BROTATO_ONLINE_LOCAL_CHARACTER_OUTLINE_DESC": "온라인 전투 중 이 기기에서 조작하는 캐릭터에만 외곽선을 추가합니다. 기본 발밑 원은 변경하지 않습니다.",
		"BROTATO_ONLINE_AUTO_JOIN_HOST_PLAYER": "호스트를 1P로 자동 추가",
		"BROTATO_ONLINE_AUTO_JOIN_HOST_PLAYER_DESC": "기본값은 켜짐입니다. 끄면 다른 플레이어가 들어오기 전에 호스트가 캐릭터 선택 화면에서 사용할 키보드/컨트롤러로 1P에 먼저 참가해 입력 장치를 확정해야 합니다. 2P가 먼저 들어오면 캐릭터 슬롯이나 포커스가 어긋날 수 있습니다.",
	},
	"ru": {
		"BROTATO_ONLINE_MENU_SETTINGS": "Онлайн-настройки",
		"BROTATO_ONLINE_SETTINGS_TITLE": "Настройки Brotato Online",
		"BROTATO_ONLINE_LOCAL_CHARACTER_OUTLINE": "Контур своего персонажа",
		"BROTATO_ONLINE_LOCAL_CHARACTER_OUTLINE_DESC": "В онлайн-бою добавляет контур только персонажу, которым управляет этот компьютер. Стандартный круг под игроком не меняется.",
		"BROTATO_ONLINE_AUTO_JOIN_HOST_PLAYER": "Автодобавление хоста как игрока 1",
		"BROTATO_ONLINE_AUTO_JOIN_HOST_PLAYER_DESC": "По умолчанию включено. Если отключить, хост должен сначала войти как игрок 1 на экране выбора персонажа с нужной клавиатурой/геймпадом, а уже затем приглашать других игроков. Если игрок 2 зайдёт раньше, слоты персонажей или фокус могут рассинхронизироваться.",
	},
	"pl": {
		"BROTATO_ONLINE_MENU_SETTINGS": "Ustawienia online",
		"BROTATO_ONLINE_SETTINGS_TITLE": "Ustawienia Brotato Online",
		"BROTATO_ONLINE_LOCAL_CHARACTER_OUTLINE": "Obrys lokalnej postaci",
		"BROTATO_ONLINE_LOCAL_CHARACTER_OUTLINE_DESC": "W walce online dodaje obrys tylko postaci sterowanej na tym komputerze. Nie zmienia domyślnego kręgu pod graczem.",
		"BROTATO_ONLINE_AUTO_JOIN_HOST_PLAYER": "Automatycznie dodaj hosta jako gracza 1",
		"BROTATO_ONLINE_AUTO_JOIN_HOST_PLAYER_DESC": "Domyślnie włączone. Po wyłączeniu host musi najpierw dołączyć jako gracz 1 na ekranie wyboru postaci, używając właściwej klawiatury/kontrolera, a dopiero potem inni gracze mogą dołączyć. Jeśli gracz 2 dołączy wcześniej, sloty postaci lub fokus mogą się rozjechać.",
	},
	"es": {
		"BROTATO_ONLINE_MENU_SETTINGS": "Ajustes online",
		"BROTATO_ONLINE_SETTINGS_TITLE": "Ajustes de Brotato Online",
		"BROTATO_ONLINE_LOCAL_CHARACTER_OUTLINE": "Contorno del personaje local",
		"BROTATO_ONLINE_LOCAL_CHARACTER_OUTLINE_DESC": "En batallas online, añade un contorno solo al personaje controlado en este equipo. No cambia el círculo original bajo los jugadores.",
		"BROTATO_ONLINE_AUTO_JOIN_HOST_PLAYER": "Añadir al anfitrión como jugador 1",
		"BROTATO_ONLINE_AUTO_JOIN_HOST_PLAYER_DESC": "Activado por defecto. Si lo desactivas, el anfitrión debe unirse primero como jugador 1 en la pantalla de selección con el teclado/mando previsto; después podrán entrar los demás. Si entra el jugador 2 antes, los huecos de personaje o el foco pueden desincronizarse.",
	},
	"pt": {
		"BROTATO_ONLINE_MENU_SETTINGS": "Configurações online",
		"BROTATO_ONLINE_SETTINGS_TITLE": "Configurações do Brotato Online",
		"BROTATO_ONLINE_LOCAL_CHARACTER_OUTLINE": "Contorno do personagem local",
		"BROTATO_ONLINE_LOCAL_CHARACTER_OUTLINE_DESC": "Em batalhas online, adiciona contorno apenas ao personagem controlado neste computador. Não altera o círculo original sob os jogadores.",
		"BROTATO_ONLINE_AUTO_JOIN_HOST_PLAYER": "Adicionar host como Jogador 1",
		"BROTATO_ONLINE_AUTO_JOIN_HOST_PLAYER_DESC": "Ativado por padrão. Se desativar, o host deve entrar primeiro como Jogador 1 na seleção de personagem usando o teclado/controle correto; só depois os outros jogadores devem entrar. Se o Jogador 2 entrar antes, os slots ou o foco podem dessincronizar.",
	},
	"de": {
		"BROTATO_ONLINE_MENU_SETTINGS": "Online-Einstellungen",
		"BROTATO_ONLINE_SETTINGS_TITLE": "Brotato Online-Einstellungen",
		"BROTATO_ONLINE_LOCAL_CHARACTER_OUTLINE": "Lokale Figur umranden",
		"BROTATO_ONLINE_LOCAL_CHARACTER_OUTLINE_DESC": "Fügt im Online-Kampf nur der auf diesem Gerät gesteuerten Figur eine Umrandung hinzu. Der originale Kreis unter Spielern bleibt unverändert.",
		"BROTATO_ONLINE_AUTO_JOIN_HOST_PLAYER": "Host automatisch als Spieler 1 hinzufügen",
		"BROTATO_ONLINE_AUTO_JOIN_HOST_PLAYER_DESC": "Standardmäßig aktiviert. Wenn deaktiviert, muss der Host zuerst im Charakterauswahlbildschirm mit der gewünschten Tastatur/dem Controller als Spieler 1 beitreten; erst danach sollten andere Spieler beitreten. Tritt Spieler 2 vorher bei, können Charakterplätze oder Fokus desynchronisieren.",
	},
	"tr": {
		"BROTATO_ONLINE_MENU_SETTINGS": "Çevrimiçi Ayarlar",
		"BROTATO_ONLINE_SETTINGS_TITLE": "Brotato Online Ayarları",
		"BROTATO_ONLINE_LOCAL_CHARACTER_OUTLINE": "Yerel karakter çerçevesi",
		"BROTATO_ONLINE_LOCAL_CHARACTER_OUTLINE_DESC": "Çevrimiçi savaşta yalnızca bu cihazda kontrol edilen karaktere çerçeve ekler. Oyuncuların altındaki varsayılan çemberi değiştirmez.",
		"BROTATO_ONLINE_AUTO_JOIN_HOST_PLAYER": "Sunucuyu Oyuncu 1 olarak otomatik ekle",
		"BROTATO_ONLINE_AUTO_JOIN_HOST_PLAYER_DESC": "Varsayılan olarak açık. Kapatırsanız, diğer oyuncular girmeden önce sunucu karakter seçim ekranında kullanacağı klavye/kontrolcü ile Oyuncu 1 olarak katılıp giriş aygıtını kesinleştirmelidir. Oyuncu 2 önce girerse karakter yuvaları veya odak senkronu bozulabilir.",
	},
	"it": {
		"BROTATO_ONLINE_MENU_SETTINGS": "Impostazioni online",
		"BROTATO_ONLINE_SETTINGS_TITLE": "Impostazioni di Brotato Online",
		"BROTATO_ONLINE_LOCAL_CHARACTER_OUTLINE": "Contorno personaggio locale",
		"BROTATO_ONLINE_LOCAL_CHARACTER_OUTLINE_DESC": "Nelle battaglie online aggiunge un contorno solo al personaggio controllato su questo computer. Non modifica il cerchio originale sotto i giocatori.",
		"BROTATO_ONLINE_AUTO_JOIN_HOST_PLAYER": "Aggiungi automaticamente l'host come giocatore 1",
		"BROTATO_ONLINE_AUTO_JOIN_HOST_PLAYER_DESC": "Attivo per impostazione predefinita. Se lo disattivi, l'host deve prima entrare come giocatore 1 nella selezione personaggio con la tastiera/controller previsto; solo dopo possono entrare gli altri. Se il giocatore 2 entra prima, slot personaggio o focus possono desincronizzarsi.",
	},
	"fr": {
		"BROTATO_ONLINE_MENU_SETTINGS": "Paramètres en ligne",
		"BROTATO_ONLINE_SETTINGS_TITLE": "Paramètres de Brotato Online",
		"BROTATO_ONLINE_LOCAL_CHARACTER_OUTLINE": "Contour du personnage local",
		"BROTATO_ONLINE_LOCAL_CHARACTER_OUTLINE_DESC": "En combat en ligne, ajoute un contour uniquement au personnage contrôlé sur cette machine. Ne modifie pas le cercle d'origine sous les joueurs.",
		"BROTATO_ONLINE_AUTO_JOIN_HOST_PLAYER": "Ajouter automatiquement l’hôte en joueur 1",
		"BROTATO_ONLINE_AUTO_JOIN_HOST_PLAYER_DESC": "Activé par défaut. Si vous le désactivez, l’hôte doit d’abord rejoindre en joueur 1 sur l’écran de sélection avec le clavier/la manette voulue, puis les autres joueurs peuvent rejoindre. Si le joueur 2 rejoint avant, les emplacements ou le focus peuvent se désynchroniser.",
	},
}


func translate(key: String) -> String:
	var builtin = TranslationServer.translate(key)
	if builtin != "" and builtin != key:
		return builtin

	var locale_candidates = _get_locale_candidates(TranslationServer.get_locale())
	for locale in locale_candidates:
		if MESSAGES.has(locale) and MESSAGES[locale].has(key):
			return str(MESSAGES[locale][key])

	return key


func _get_locale_candidates(locale: String) -> Array:
	var normalized = locale.replace("-", "_")
	var candidates = []

	if normalized.begins_with("zh_TW") or normalized.begins_with("zh_HK") or normalized.begins_with("zh_Hant"):
		candidates.append("zh_TW")
	elif normalized.begins_with("zh"):
		candidates.append("zh")

	if normalized != "" and not candidates.has(normalized):
		candidates.append(normalized)

	var base = normalized.split("_")[0] if normalized.find("_") != -1 else normalized
	if base != "" and not candidates.has(base):
		candidates.append(base)

	if not candidates.has(FALLBACK_LOCALE):
		candidates.append(FALLBACK_LOCALE)

	return candidates
