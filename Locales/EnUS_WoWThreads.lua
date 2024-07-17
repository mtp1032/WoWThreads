-- Filename: EnUs_WoWThreads.lua
local ADDON_NAME, _ = ...

-- Create a new library instance, or get the existing one
local LibStub = LibStub
local LIBSTUB_MAJOR, LIBSTUB_MINOR = "EnUSlib", 1
local LibStub = LibStub -- If LibStub is not global, adjust accordingly
local EnUSlib, oldVersion = LibStub:NewLibrary(LIBSTUB_MAJOR, LIBSTUB_MINOR)
if not EnUSlib then 
    return 
end

-- Form a string representing the library's version number (see WoWThreads.lua).
local MAJOR = C_AddOns.GetAddOnMetadata(ADDON_NAME, "X-MAJOR")
local MINOR = C_AddOns.GetAddOnMetadata(ADDON_NAME, "X-MINOR")
local PATCH = C_AddOns.GetAddOnMetadata(ADDON_NAME, "X-PATCH")

local version = string.format("%s.%s.%s", MAJOR, MINOR, PATCH )

local tickInterval = 1000 / GetFramerate() -- Milliseconds
local function getExpansionName( )
    local expansionLevel = GetExpansionLevel()
    local expansionNames = { -- Use a table to map expansion levels to names
        [LE_EXPANSION_DRAGONFLIGHT] = "Dragon Flight",
        [LE_EXPANSION_SHADOWLANDS] = "Shadowlands",
        [LE_EXPANSION_CATACLYSM] = "Classic (Cataclysm)",
        [LE_EXPANSION_WRATH_OF_THE_LICH_KING] = "Classic (WotLK)",
        [LE_EXPANSION_CLASSIC] = "Classic (Vanilla)",

        [LE_EXPANSION_MISTS_OF_PANDARIA] = "Classic (Mists of Pandaria",
        [LE_EXPANSION_LEGION] = "Classic (Legion)",
        [LE_EXPANSION_BATTLE_FOR_AZEROTH] = "Classic (Battle for Azeroth)",
        [10]   = "The War Within"
    }
    return expansionNames[expansionLevel] -- Directly return the mapped name
end

-- =====================================================================
--                      LOCALIZATION
-- =====================================================================
local L = setmetatable({}, { __index = function(t, k) 
	local v = tostring(k)
	rawset(t, k, v)
	return v
end })

EnUSlib.L = L
local LOCALE = GetLocale()

if LOCALE == "enUS" then

    L["WOWTHREADS_NAME"]            = ADDON_NAME
    L["VERSION"] 			        = version
    L["EXPANSION_NAME"]             = getExpansionName()
    L["WOWTHREADS_VERSION"]         = string.format("%s (%s)", L["WOWTHREADS_NAME"], L["VERSION"])
    L["TICK_INTERVAL"]              = string.format("Clock Interval: %0.3f ms", tickInterval )
    L["WOWTHREADS_OPTIONS"]         = string.format("%s Options", L["WOWTHREADS_NAME"] )     -- "WoWThreads Options"
    L["WOWTHREADS_OPTIONS_MENU"]    = string.format("%s Menu", L["WOWTHREADS_OPTIONS"])
    L["WOWTHREADS_AND_VERSION"]    = string.format("%s %s (%s)", L["WOWTHREADS_NAME"], L["VERSION"], L["EXPANSION_NAME"]  )
	L["ADDON_MESSAGE"]		       = string.format("%s loaded. ", L["WOWTHREADS_AND_VERSION"])
    L["ERROR_MSG_FRAME_TITLE"]     = string.format("%s Error Messages.", L["WOWTHREADS_AND_VERSION"]  )

    --                      Minimap Options Menu Localizations
    L["NOTIFICATION_FRAME_TITLE"]   = string.format( "Notifications - %s ",  L["WOWTHREADS_VERSION"])
    L["LINE1"] = "    WoWThreads is a library of services that enable developers"
    L["LINE2"] = "to incorporate asynchronous, non-preemptive multithreading into"
    L["LINE3"] = "their addons. You can read more about thread programming generally,"
    L["LINE4"] = "and WoWThreads specifically. See, WoWThreads-complete.md in the"
    L["LINE5"] = "Docs subdirectory."

    L["ACCEPT_BUTTON_LABEL"]    = "Accept"
    L["DISMISS_BUTTON_LABEL"]   = "Dismiss"

    L["ENABLE_DATA_COLLECTION"] = "Check to collect system overhead data."
    L["TOOTIP_DATA_COLLECTION"] = "If checked, the system overhead per thread will be collected."

    L["ENABLE_ERROR_LOGGING"]   = "Check to enable error logging."
    L["TOOLTIP_DEBUGGING"]      = "If checked, writes additional error information to the Chat Window."

    --                          Generic Error MessageS
	L["WRONG_TYPE"]		= "ERROR: Datatype unexpected "
    L["PARAMETER_NIL"]  = "ERROR: Parameter nil "

	--                          Thread-specific messages
	L["THREAD_HANDLE_NIL"] 		    = "ERROR: Thread handle nil "
    L["THREAD_HANDLE_WRONG_TYPE"]   = "ERROR: Invalid handle. Wrong type. Should be type 'table' "
	L["THREAD_NO_COROUTINE"]        = "ERROR: Handle does not reference a coroutine "
    L["THREAD_INVALID_CONTEXT"]     = "ERROR: Caller is likely the WoW client (WoW.exe) "
	L["THREAD_HANDLE_ILL_FORMED"]	= "ERROR: Thread handle ill-formed. Check table size. "
    L["THREAD_NOT_SLEEPING"]        = "ERROR: Thread handle not found in sleep queue. "

	L["THREAD_COROUTINE_DEAD"]      = "ERROR: Invalid handle. Thread has completed or faulted. "
    L["THREAD_NOT_FOUND"]           = "ERROR: Thread not found. "

    -- Signal failure
	L["SIGNAL_OUT_OF_RANGE"]	    = "ERROR: Signal is out of range "
    L["SIGNAL_IS_NIL"]	            = "ERROR: Signal is unknown or nil "
    L["SIGNAL_INVALID_TYPE"]        = "ERROR: Signal type is invalid. Should be 'number' "
    L["SIGNAL_INVALID_OPERATION"]   = "ERROR: SIG_NONE_PENDING can not be sent "
end
if LOCALE == "frFR" then
    L["WOWTHREADS_NAME"]            = ADDON_NAME
    L["VERSION"]                    = version
    L["EXPANSION_NAME"]             = getExpansionName()
    L["WOWTHREADS_VERSION"]         = string.format("%s (%s)", L["WOWTHREADS_NAME"], L["VERSION"])
    L["TICK_INTERVAL"]              = string.format("Intervalle d'horloge : %0.3f ms", tickInterval)
    L["WOWTHREADS_OPTIONS"]         = string.format("Options de %s", L["WOWTHREADS_NAME"])
    L["WOWTHREADS_OPTIONS_MENU"]    = string.format("Menu des options de %s", L["WOWTHREADS_OPTIONS"])
    L["WOWTHREADS_AND_VERSION"]     = string.format("%s %s (%s)", L["WOWTHREADS_NAME"], L["VERSION"], L["EXPANSION_NAME"])
    L["ADDON_MESSAGE"]              = string.format("%s chargé.", L["WOWTHREADS_AND_VERSION"])
    L["ERROR_MSG_FRAME_TITLE"]      = string.format("Messages d'erreur de %s.", L["WOWTHREADS_AND_VERSION"])

    L["NOTIFICATION_FRAME_TITLE"]   = string.format("Notifications - %s", L["WOWTHREADS_VERSION"])
    L["LINE1"] = "    WoWThreads est une bibliothèque de services qui permet aux développeurs"
    L["LINE2"] = "d'incorporer le multithreading asynchrone et non préemptif dans"
    L["LINE3"] = "leurs addons. Vous pouvez en savoir plus sur la programmation des threads en général,"
    L["LINE4"] = "et WoWThreads en particulier. Voir, WoWThreads-complete.md dans le"
    L["LINE5"] = "sous-répertoire Docs."

    L["ACCEPT_BUTTON_LABEL"]    = "Accepter"
    L["DISMISS_BUTTON_LABEL"]   = "Fermer"

    L["ENABLE_DATA_COLLECTION"] = "Cochez pour collecter les données de surcharge du système."
    L["TOOTIP_DATA_COLLECTION"] = "Si coché, la surcharge du système par thread sera collectée."

    L["ENABLE_ERROR_LOGGING"]   = "Cochez pour activer la journalisation des erreurs."
    L["TOOLTIP_DEBUGGING"]      = "Si coché, des informations d'erreur supplémentaires seront écrites dans la fenêtre de chat."

    L["WRONG_TYPE"]             = "ERREUR : Type de donnée inattendu"
    L["PARAMETER_NIL"]          = "ERREUR : Paramètre nul"

    L["THREAD_HANDLE_NIL"]      = "ERREUR : Gestionnaire de thread nul"
    L["THREAD_HANDLE_WRONG_TYPE"] = "ERREUR : Gestionnaire invalide. Mauvais type. Doit être de type 'table'"
    L["THREAD_NO_COROUTINE"]    = "ERREUR : Le gestionnaire ne fait pas référence à une coroutine"
    L["THREAD_INVALID_CONTEXT"] = "ERREUR : L'appelant est probablement le client WoW (WoW.exe)"
    L["THREAD_HANDLE_ILL_FORMED"] = "ERREUR : Gestionnaire de thread mal formé. Vérifiez la taille de la table."

    L["THREAD_COROUTINE_DEAD"]  = "ERREUR : Gestionnaire invalide. Le thread est terminé ou en panne."
    L["THREAD_NOT_FOUND"]       = "ERREUR : Thread introuvable."

    L["SIGNAL_OUT_OF_RANGE"]    = "ERREUR : Signal hors de portée"
    L["SIGNAL_IS_NIL"]          = "ERREUR : Signal inconnu ou nul"
    L["SIGNAL_INVALID_TYPE"]    = "ERREUR : Type de signal invalide. Doit être 'number'"
    L["SIGNAL_INVALID_OPERATION"] = "ERREUR : SIG_NONE_PENDING ne peut pas être envoyé"
end
if LOCALE == "deDE" then
    L["WOWTHREADS_NAME"]            = ADDON_NAME
    L["VERSION"]                    = version
    L["EXPANSION_NAME"]             = getExpansionName()
    L["WOWTHREADS_VERSION"]         = string.format("%s (%s)", L["WOWTHREADS_NAME"], L["VERSION"])
    L["TICK_INTERVAL"]              = string.format("Taktintervall: %0.3f ms", tickInterval)
    L["WOWTHREADS_OPTIONS"]         = string.format("%s Optionen", L["WOWTHREADS_NAME"])
    L["WOWTHREADS_OPTIONS_MENU"]    = string.format("%s Menü", L["WOWTHREADS_OPTIONS"])
    L["WOWTHREADS_AND_VERSION"]     = string.format("%s %s (%s)", L["WOWTHREADS_NAME"], L["VERSION"], L["EXPANSION_NAME"])
    L["ADDON_MESSAGE"]              = string.format("%s geladen.", L["WOWTHREADS_AND_VERSION"])
    L["ERROR_MSG_FRAME_TITLE"]      = string.format("%s Fehlermeldungen.", L["WOWTHREADS_AND_VERSION"])

    L["NOTIFICATION_FRAME_TITLE"]   = string.format("Benachrichtigungen - %s", L["WOWTHREADS_VERSION"])
    L["LINE1"] = "    WoWThreads ist eine Bibliothek von Diensten, die es Entwicklern ermöglicht"
    L["LINE2"] = "asynchrones, nicht-preemptives Multithreading in ihre Addons zu integrieren."
    L["LINE3"] = "Sie können mehr über Thread-Programmierung im Allgemeinen und"
    L["LINE4"] = "WoWThreads im Besonderen lesen. Siehe WoWThreads-complete.md im"
    L["LINE5"] = "Unterverzeichnis Docs."

    L["ACCEPT_BUTTON_LABEL"]    = "Akzeptieren"
    L["DISMISS_BUTTON_LABEL"]   = "Schließen"

    L["ENABLE_DATA_COLLECTION"] = "Ankreuzen, um System-Overhead-Daten zu sammeln."
    L["TOOTIP_DATA_COLLECTION"] = "Wenn angekreuzt, wird der System-Overhead pro Thread gesammelt."

    L["ENABLE_ERROR_LOGGING"]   = "Ankreuzen, um Fehlerprotokollierung zu aktivieren."
    L["TOOLTIP_DEBUGGING"]      = "Wenn angekreuzt, werden zusätzliche Fehlerinformationen im Chatfenster geschrieben."

    L["WRONG_TYPE"]             = "FEHLER: Unerwarteter Datentyp"
    L["PARAMETER_NIL"]          = "FEHLER: Parameter null"

    L["THREAD_HANDLE_NIL"]      = "FEHLER: Thread-Handle null"
    L["THREAD_HANDLE_WRONG_TYPE"] = "FEHLER: Ungültiges Handle. Falscher Typ. Sollte vom Typ 'table' sein"
    L["THREAD_NO_COROUTINE"]    = "FEHLER: Handle verweist nicht auf eine Coroutine"
    L["THREAD_INVALID_CONTEXT"] = "FEHLER: Anrufer ist wahrscheinlich der WoW-Client (WoW.exe)"
    L["THREAD_HANDLE_ILL_FORMED"] = "FEHLER: Thread-Handle schlecht geformt. Überprüfen Sie die Tabellengröße."

    L["THREAD_COROUTINE_DEAD"]  = "FEHLER: Ungültiges Handle. Thread ist abgeschlossen oder fehlgeschlagen."
    L["THREAD_NOT_FOUND"]       = "FEHLER: Thread nicht gefunden."

    L["SIGNAL_OUT_OF_RANGE"]    = "FEHLER: Signal außerhalb des Bereichs"
    L["SIGNAL_IS_NIL"]          = "FEHLER: Signal unbekannt oder null"
    L["SIGNAL_INVALID_TYPE"]    = "FEHLER: Ungültiger Signaltyp. Sollte 'number' sein"
    L["SIGNAL_INVALID_OPERATION"] = "FEHLER: SIG_NONE_PENDING kann nicht gesendet werden"
end
if LOCALE == "itIT" then
    L["WOWTHREADS_NAME"]            = ADDON_NAME
    L["VERSION"]                    = version
    L["EXPANSION_NAME"]             = getExpansionName()
    L["WOWTHREADS_VERSION"]         = string.format("%s (%s)", L["WOWTHREADS_NAME"], L["VERSION"])
    L["TICK_INTERVAL"]              = string.format("Intervallo di clock: %0.3f ms", tickInterval)
    L["WOWTHREADS_OPTIONS"]         = string.format("Opzioni di %s", L["WOWTHREADS_NAME"])
    L["WOWTHREADS_OPTIONS_MENU"]    = string.format("Menu delle opzioni di %s", L["WOWTHREADS_OPTIONS"])
    L["WOWTHREADS_AND_VERSION"]     = string.format("%s %s (%s)", L["WOWTHREADS_NAME"], L["VERSION"], L["EXPANSION_NAME"])
    L["ADDON_MESSAGE"]              = string.format("%s caricato.", L["WOWTHREADS_AND_VERSION"])
    L["ERROR_MSG_FRAME_TITLE"]      = string.format("Messaggi di errore di %s.", L["WOWTHREADS_AND_VERSION"])

    L["NOTIFICATION_FRAME_TITLE"]   = string.format("Notifiche - %s", L["WOWTHREADS_VERSION"])
    L["LINE1"] = "    WoWThreads è una libreria di servizi che consente agli sviluppatori"
    L["LINE2"] = "di incorporare il multithreading asincrono e non preemptivo nei"
    L["LINE3"] = "loro addon. Puoi leggere di più sulla programmazione dei thread in generale,"
    L["LINE4"] = "e su WoWThreads in particolare. Vedi, WoWThreads-complete.md nella"
    L["LINE5"] = "sottodirectory Docs."

    L["ACCEPT_BUTTON_LABEL"]    = "Accetta"
    L["DISMISS_BUTTON_LABEL"]   = "Chiudi"

    L["ENABLE_DATA_COLLECTION"] = "Seleziona per raccogliere i dati di overhead del sistema."
    L["TOOTIP_DATA_COLLECTION"] = "Se selezionato, verrà raccolto l'overhead del sistema per thread."

    L["ENABLE_ERROR_LOGGING"]   = "Seleziona per abilitare il logging degli errori."
    L["TOOLTIP_DEBUGGING"]      = "Se selezionato, verranno scritte ulteriori informazioni sugli errori nella finestra della chat."

    L["WRONG_TYPE"]             = "ERRORE: Tipo di dato inaspettato"
    L["PARAMETER_NIL"]          = "ERRORE: Parametro nullo"

    L["THREAD_HANDLE_NIL"]      = "ERRORE: Gestore del thread nullo"
    L["THREAD_HANDLE_WRONG_TYPE"] = "ERRORE: Gestore non valido. Tipo sbagliato. Dovrebbe essere di tipo 'table'"
    L["THREAD_NO_COROUTINE"]    = "ERRORE: Il gestore non fa riferimento a una coroutine"
    L["THREAD_INVALID_CONTEXT"] = "ERRORE: Il chiamante è probabilmente il client di WoW (WoW.exe)"
    L["THREAD_HANDLE_ILL_FORMED"] = "ERRORE: Gestore del thread mal formato. Controlla la dimensione della tabella."

    L["THREAD_COROUTINE_DEAD"]  = "ERRORE: Gestore non valido. Il thread è completato o fallito."
    L["THREAD_NOT_FOUND"]       = "ERRORE: Thread non trovato."

    L["SIGNAL_OUT_OF_RANGE"]    = "ERRORE: Segnale fuori portata"
    L["SIGNAL_IS_NIL"]          = "ERRORE: Segnale sconosciuto o nullo"
    L["SIGNAL_INVALID_TYPE"]    = "ERRORE: Tipo di segnale non valido. Dovrebbe essere 'number'"
    L["SIGNAL_INVALID_OPERATION"] = "ERRORE: SIG_NONE_PENDING non può essere inviato"
end
if LOCALE == "ptBR" then
    L["WOWTHREADS_NAME"]            = ADDON_NAME
    L["VERSION"]                    = version
    L["EXPANSION_NAME"]             = getExpansionName()
    L["WOWTHREADS_VERSION"]         = string.format("%s (%s)", L["WOWTHREADS_NAME"], L["VERSION"])
    L["TICK_INTERVAL"]              = string.format("Intervalo do relógio: %0.3f ms", tickInterval)
    L["WOWTHREADS_OPTIONS"]         = string.format("Opções de %s", L["WOWTHREADS_NAME"])
    L["WOWTHREADS_OPTIONS_MENU"]    = string.format("Menu de opções de %s", L["WOWTHREADS_OPTIONS"])
    L["WOWTHREADS_AND_VERSION"]     = string.format("%s %s (%s)", L["WOWTHREADS_NAME"], L["VERSION"], L["EXPANSION_NAME"])
    L["ADDON_MESSAGE"]              = string.format("%s carregado.", L["WOWTHREADS_AND_VERSION"])
    L["ERROR_MSG_FRAME_TITLE"]      = string.format("Mensagens de erro de %s.", L["WOWTHREADS_AND_VERSION"])

    L["NOTIFICATION_FRAME_TITLE"]   = string.format("Notificações - %s", L["WOWTHREADS_VERSION"])
    L["LINE1"] = "    WoWThreads é uma biblioteca de serviços que permite aos desenvolvedores"
    L["LINE2"] = "incorporar multithreading assíncrono e não preemptivo em seus"
    L["LINE3"] = "addons. Você pode ler mais sobre programação de threads em geral,"
    L["LINE4"] = "e WoWThreads em particular. Veja, WoWThreads-complete.md no"
    L["LINE5"] = "subdiretório Docs."

    L["ACCEPT_BUTTON_LABEL"]    = "Aceitar"
    L["DISMISS_BUTTON_LABEL"]   = "Fechar"

    L["ENABLE_DATA_COLLECTION"] = "Marque para coletar dados de sobrecarga do sistema."
    L["TOOTIP_DATA_COLLECTION"] = "Se marcado, a sobrecarga do sistema por thread será coletada."

    L["ENABLE_ERROR_LOGGING"]   = "Marque para ativar o registro de erros."
    L["TOOLTIP_DEBUGGING"]      = "Se marcado, informações adicionais de erro serão escritas na janela de bate-papo."

    L["WRONG_TYPE"]             = "ERRO: Tipo de dado inesperado"
    L["PARAMETER_NIL"]          = "ERRO: Parâmetro nulo"

    L["THREAD_HANDLE_NIL"]      = "ERRO: Manipulador de thread nulo"
    L["THREAD_HANDLE_WRONG_TYPE"] = "ERRO: Manipulador inválido. Tipo errado. Deve ser do tipo 'table'"
    L["THREAD_NO_COROUTINE"]    = "ERRO: O manipulador não faz referência a uma coroutine"
    L["THREAD_INVALID_CONTEXT"] = "ERRO: O chamador é provavelmente o cliente do WoW (WoW.exe)"
    L["THREAD_HANDLE_ILL_FORMED"] = "ERRO: Manipulador de thread mal formado. Verifique o tamanho da tabela."

    L["THREAD_COROUTINE_DEAD"]  = "ERRO: Manipulador inválido. O thread foi concluído ou falhou."
    L["THREAD_NOT_FOUND"]       = "ERRO: Thread não encontrado."

    L["SIGNAL_OUT_OF_RANGE"]    = "ERRO: Sinal fora do intervalo"
    L["SIGNAL_IS_NIL"]          = "ERRO: Sinal desconhecido ou nulo"
    L["SIGNAL_INVALID_TYPE"]    = "ERRO: Tipo de sinal inválido. Deve ser 'number'"
    L["SIGNAL_INVALID_OPERATION"] = "ERRO: SIG_NONE_PENDING não pode ser enviado"
end
if LOCALE == "koKR" then
    L["WOWTHREADS_NAME"]            = ADDON_NAME
    L["VERSION"]                    = version
    L["EXPANSION_NAME"]             = getExpansionName()
    L["WOWTHREADS_VERSION"]         = string.format("%s (%s)", L["WOWTHREADS_NAME"], L["VERSION"])
    L["TICK_INTERVAL"]              = string.format("시계 간격: %0.3f ms", tickInterval)
    L["WOWTHREADS_OPTIONS"]         = string.format("%s 옵션", L["WOWTHREADS_NAME"])
    L["WOWTHREADS_OPTIONS_MENU"]    = string.format("%s 메뉴", L["WOWTHREADS_OPTIONS"])
    L["WOWTHREADS_AND_VERSION"]     = string.format("%s %s (%s)", L["WOWTHREADS_NAME"], L["VERSION"], L["EXPANSION_NAME"])
    L["ADDON_MESSAGE"]              = string.format("%s 로드됨.", L["WOWTHREADS_AND_VERSION"])
    L["ERROR_MSG_FRAME_TITLE"]      = string.format("%s 오류 메시지.", L["WOWTHREADS_AND_VERSION"])

    L["NOTIFICATION_FRAME_TITLE"]   = string.format("알림 - %s", L["WOWTHREADS_VERSION"])
    L["LINE1"] = "    WoWThreads는 개발자가"
    L["LINE2"] = "비선점형 비동기 멀티스레딩을"
    L["LINE3"] = "애드온에 통합할 수 있도록 도와주는 라이브러리입니다."
    L["LINE4"] = "일반적인 스레드 프로그래밍과 WoWThreads에 대해 더 알고 싶다면,"
    L["LINE5"] = "Docs 하위 디렉토리의 WoWThreads-complete.md를 참조하세요."

    L["ACCEPT_BUTTON_LABEL"]    = "수락"
    L["DISMISS_BUTTON_LABEL"]   = "닫기"

    L["ENABLE_DATA_COLLECTION"] = "시스템 오버헤드 데이터를 수집하려면 체크하세요."
    L["TOOTIP_DATA_COLLECTION"] = "체크하면 스레드 당 시스템 오버헤드가 수집됩니다."

    L["ENABLE_ERROR_LOGGING"]   = "오류 로깅을 활성화하려면 체크하세요."
    L["TOOLTIP_DEBUGGING"]      = "체크하면 추가 오류 정보가 채팅 창에 기록됩니다."

    L["WRONG_TYPE"]             = "오류: 예상하지 못한 데이터 유형"
    L["PARAMETER_NIL"]          = "오류: 매개변수가 nil입니다."

    L["THREAD_HANDLE_NIL"]      = "오류: 스레드 핸들이 nil입니다."
    L["THREAD_HANDLE_WRONG_TYPE"] = "오류: 잘못된 핸들. 잘못된 유형. 'table' 유형이어야 합니다."
    L["THREAD_NO_COROUTINE"]    = "오류: 핸들이 코루틴을 참조하지 않습니다."
    L["THREAD_INVALID_CONTEXT"] = "오류: 호출자가 아마 WoW 클라이언트(WoW.exe)일 것입니다."
    L["THREAD_HANDLE_ILL_FORMED"] = "오류: 스레드 핸들이 잘못되었습니다. 테이블 크기를 확인하세요."

    L["THREAD_COROUTINE_DEAD"]  = "오류: 잘못된 핸들. 스레드가 완료되었거나 오류가 발생했습니다."
    L["THREAD_NOT_FOUND"]       = "오류: 스레드를 찾을 수 없습니다."

    L["SIGNAL_OUT_OF_RANGE"]    = "오류: 신호가 범위를 벗어났습니다."
    L["SIGNAL_IS_NIL"]          = "오류: 신호가 알 수 없거나 nil입니다."
    L["SIGNAL_INVALID_TYPE"]    = "오류: 잘못된 신호 유형. 'number'이어야 합니다."
    L["SIGNAL_INVALID_OPERATION"] = "오류: SIG_NONE_PENDING을 보낼 수 없습니다."
end
if LOCALE == "ruRU" then
    L["WOWTHREADS_NAME"]            = ADDON_NAME
    L["VERSION"]                    = version
    L["EXPANSION_NAME"]             = getExpansionName()
    L["WOWTHREADS_VERSION"]         = string.format("%s (%s)", L["WOWTHREADS_NAME"], L["VERSION"])
    L["TICK_INTERVAL"]              = string.format("Интервал такта: %0.3f мс", tickInterval)
    L["WOWTHREADS_OPTIONS"]         = string.format("Параметры %s", L["WOWTHREADS_NAME"])
    L["WOWTHREADS_OPTIONS_MENU"]    = string.format("Меню параметров %s", L["WOWTHREADS_OPTIONS"])
    L["WOWTHREADS_AND_VERSION"]     = string.format("%s %s (%s)", L["WOWTHREADS_NAME"], L["VERSION"], L["EXPANSION_NAME"])
    L["ADDON_MESSAGE"]              = string.format("%s загружен.", L["WOWTHREADS_AND_VERSION"])
    L["ERROR_MSG_FRAME_TITLE"]      = string.format("Сообщения об ошибках %s.", L["WOWTHREADS_AND_VERSION"])

    L["NOTIFICATION_FRAME_TITLE"]   = string.format("Уведомления - %s", L["WOWTHREADS_VERSION"])
    L["LINE1"] = "    WoWThreads - это библиотека услуг, которая позволяет разработчикам"
    L["LINE2"] = "внедрять асинхронную, невырывающую многопоточность в их аддоны."
    L["LINE3"] = "Вы можете узнать больше о программировании потоков в целом,"
    L["LINE4"] = "и о WoWThreads в частности. Смотрите WoWThreads-complete.md в"
    L["LINE5"] = "подкаталоге Docs."

    L["ACCEPT_BUTTON_LABEL"]    = "Принять"
    L["DISMISS_BUTTON_LABEL"]   = "Закрыть"

    L["ENABLE_DATA_COLLECTION"] = "Отметьте, чтобы собирать данные о системных издержках."
    L["TOOTIP_DATA_COLLECTION"] = "Если отмечено, будут собираться системные издержки на поток."

    L["ENABLE_ERROR_LOGGING"]   = "Отметьте, чтобы включить ведение журнала ошибок."
    L["TOOLTIP_DEBUGGING"]      = "Если отмечено, будут записываться дополнительные сведения об ошибках в окно чата."

    L["WRONG_TYPE"]             = "ОШИБКА: Неожиданный тип данных"
    L["PARAMETER_NIL"]          = "ОШИБКА: Параметр nil"

    L["THREAD_HANDLE_NIL"]      = "ОШИБКА: Обработчик потока nil"
    L["THREAD_HANDLE_WRONG_TYPE"] = "ОШИБКА: Неверный обработчик. Неправильный тип. Должен быть типа 'table'"
    L["THREAD_NO_COROUTINE"]    = "ОШИБКА: Обработчик не ссылается на сопрограмму"
    L["THREAD_INVALID_CONTEXT"] = "ОШИБКА: Вызывающим лицом, вероятно, является клиент WoW (WoW.exe)"
    L["THREAD_HANDLE_ILL_FORMED"] = "ОШИБКА: Обработчик потока неправильно сформирован. Проверьте размер таблицы."

    L["THREAD_COROUTINE_DEAD"]  = "ОШИБКА: Неверный обработчик. Поток завершен или произошел сбой."
    L["THREAD_NOT_FOUND"]       = "ОШИБКА: Поток не найден."

    L["SIGNAL_OUT_OF_RANGE"]    = "ОШИБКА: Сигнал вне диапазона"
    L["SIGNAL_IS_NIL"]          = "ОШИБКА: Сигнал неизвестен или nil"
    L["SIGNAL_INVALID_TYPE"]    = "ОШИБКА: Неверный тип сигнала. Должен быть 'number'"
    L["SIGNAL_INVALID_OPERATION"] = "ОШИБКА: SIG_NONE_PENDING не может быть отправлен"
end
if LOCALE == "esES" or LOCALE == "esMX" then
    L["WOWTHREADS_NAME"]            = ADDON_NAME
    L["VERSION"]                    = version
    L["EXPANSION_NAME"]             = getExpansionName()
    L["WOWTHREADS_VERSION"]         = string.format("%s (%s)", L["WOWTHREADS_NAME"], L["VERSION"])
    L["TICK_INTERVAL"]              = string.format("Intervalo de reloj: %0.3f ms", tickInterval)
    L["WOWTHREADS_OPTIONS"]         = string.format("Opciones de %s", L["WOWTHREADS_NAME"])
    L["WOWTHREADS_OPTIONS_MENU"]    = string.format("Menú de opciones de %s", L["WOWTHREADS_OPTIONS"])
    L["WOWTHREADS_AND_VERSION"]     = string.format("%s %s (%s)", L["WOWTHREADS_NAME"], L["VERSION"], L["EXPANSION_NAME"])
    L["ADDON_MESSAGE"]              = string.format("%s cargado.", L["WOWTHREADS_AND_VERSION"])
    L["ERROR_MSG_FRAME_TITLE"]      = string.format("Mensajes de error de %s.", L["WOWTHREADS_AND_VERSION"])

    L["NOTIFICATION_FRAME_TITLE"]   = string.format("Notificaciones - %s", L["WOWTHREADS_VERSION"])
    L["LINE1"] = "    WoWThreads es una biblioteca de servicios que permite a los desarrolladores"
    L["LINE2"] = "incorporar multithreading asíncrono y no preventivo en sus"
    L["LINE3"] = "addons. Puedes leer más sobre la programación de hilos en general,"
    L["LINE4"] = "y WoWThreads en particular. Ver, WoWThreads-complete.md en el"
    L["LINE5"] = "subdirectorio Docs."

    L["ACCEPT_BUTTON_LABEL"]    = "Aceptar"
    L["DISMISS_BUTTON_LABEL"]   = "Cerrar"

    L["ENABLE_DATA_COLLECTION"] = "Marque para recopilar datos de sobrecarga del sistema."
    L["TOOTIP_DATA_COLLECTION"] = "Si está marcado, se recopilará la sobrecarga del sistema por hilo."

    L["ENABLE_ERROR_LOGGING"]   = "Marque para habilitar el registro de errores."
    L["TOOLTIP_DEBUGGING"]      = "Si está marcado, se escribirán informaciones adicionales de error en la ventana de chat."

    L["WRONG_TYPE"]             = "ERROR: Tipo de dato inesperado"
    L["PARAMETER_NIL"]          = "ERROR: Parámetro nil"

    L["THREAD_HANDLE_NIL"]      = "ERROR: Manejador de hilo nil"
    L["THREAD_HANDLE_WRONG_TYPE"] = "ERROR: Manejador inválido. Tipo incorrecto. Debería ser de tipo 'table'"
    L["THREAD_NO_COROUTINE"]    = "ERROR: El manejador no hace referencia a una corrutina"
    L["THREAD_INVALID_CONTEXT"] = "ERROR: El llamador probablemente sea el cliente de WoW (WoW.exe)"
    L["THREAD_HANDLE_ILL_FORMED"] = "ERROR: Manejador de hilo mal formado. Verifique el tamaño de la tabla."

    L["THREAD_COROUTINE_DEAD"]  = "ERROR: Manejador inválido. El hilo ha completado o fallado."
    L["THREAD_NOT_FOUND"]       = "ERROR: Hilo no encontrado."

    L["SIGNAL_OUT_OF_RANGE"]    = "ERROR: Señal fuera de rango"
    L["SIGNAL_IS_NIL"]          = "ERROR: Señal desconocida o nil"
    L["SIGNAL_INVALID_TYPE"]    = "ERROR: Tipo de señal inválido. Debería ser 'number'"
    L["SIGNAL_INVALID_OPERATION"] = "ERROR: SIG_NONE_PENDING no se puede enviar"
end
if LOCALE == "zhTW" then
    L["WOWTHREADS_NAME"]            = ADDON_NAME
    L["VERSION"]                    = version
    L["EXPANSION_NAME"]             = getExpansionName()
    L["WOWTHREADS_VERSION"]         = string.format("%s (%s)", L["WOWTHREADS_NAME"], L["VERSION"])
    L["TICK_INTERVAL"]              = string.format("時鐘間隔：%0.3f 毫秒", tickInterval)
    L["WOWTHREADS_OPTIONS"]         = string.format("%s 選項", L["WOWTHREADS_NAME"])
    L["WOWTHREADS_OPTIONS_MENU"]    = string.format("%s 菜單", L["WOWTHREADS_OPTIONS"])
    L["WOWTHREADS_AND_VERSION"]     = string.format("%s %s (%s)", L["WOWTHREADS_NAME"], L["VERSION"], L["EXPANSION_NAME"])
    L["ADDON_MESSAGE"]              = string.format("%s 已加載。", L["WOWTHREADS_AND_VERSION"])
    L["ERROR_MSG_FRAME_TITLE"]      = string.format("%s 錯誤信息。", L["WOWTHREADS_AND_VERSION"])

    L["NOTIFICATION_FRAME_TITLE"]   = string.format("通知 - %s", L["WOWTHREADS_VERSION"])
    L["LINE1"] = "    WoWThreads 是一個服務庫，使開發人員能夠"
    L["LINE2"] = "將非搶占式異步多線程集成到"
    L["LINE3"] = "他們的插件中。您可以閱讀更多有關線程編程的一般信息，"
    L["LINE4"] = "尤其是有關 WoWThreads 的信息。請參閱 Docs 子目錄中的 WoWThreads-complete.md。"

    L["ACCEPT_BUTTON_LABEL"]    = "接受"
    L["DISMISS_BUTTON_LABEL"]   = "關閉"

    L["ENABLE_DATA_COLLECTION"] = "選中以收集系統開銷數據。"
    L["TOOTIP_DATA_COLLECTION"] = "如果選中，將收集每個線程的系統開銷。"

    L["ENABLE_ERROR_LOGGING"]   = "選中以啟用錯誤日誌記錄。"
    L["TOOLTIP_DEBUGGING"]      = "如果選中，將在聊天窗口中寫入更多的錯誤信息。"

    L["WRONG_TYPE"]             = "錯誤：意外的數據類型"
    L["PARAMETER_NIL"]          = "錯誤：參數為 nil"

    L["THREAD_HANDLE_NIL"]      = "錯誤：線程句柄為 nil"
    L["THREAD_HANDLE_WRONG_TYPE"] = "錯誤：無效的句柄。類型錯誤。應為 'table' 類型"
    L["THREAD_NO_COROUTINE"]    = "錯誤：句柄不引用協程"
    L["THREAD_INVALID_CONTEXT"] = "錯誤：調用者可能是 WoW 客戶端（WoW.exe）"
    L["THREAD_HANDLE_ILL_FORMED"] = "錯誤：線程句柄格式錯誤。檢查表格大小。"

    L["THREAD_COROUTINE_DEAD"]  = "錯誤：無效的句柄。線程已完成或失敗。"
    L["THREAD_NOT_FOUND"]       = "錯誤：找不到線程。"

    L["SIGNAL_OUT_OF_RANGE"]    = "錯誤：信號超出範圍"
    L["SIGNAL_IS_NIL"]          = "錯誤：信號未知或為 nil"
    L["SIGNAL_INVALID_TYPE"]    = "錯誤：信號類型無效。應為 'number'"
    L["SIGNAL_INVALID_OPERATION"] = "錯誤：SIG_NONE_PENDING 無法發送"
end
if LOCALE == "zhCN" then
    L["WOWTHREADS_NAME"]            = ADDON_NAME
    L["VERSION"]                    = version
    L["EXPANSION_NAME"]             = getExpansionName()
    L["WOWTHREADS_VERSION"]         = string.format("%s (%s)", L["WOWTHREADS_NAME"], L["VERSION"])
    L["TICK_INTERVAL"]              = string.format("时钟间隔：%0.3f 毫秒", tickInterval)
    L["WOWTHREADS_OPTIONS"]         = string.format("%s 选项", L["WOWTHREADS_NAME"])
    L["WOWTHREADS_OPTIONS_MENU"]    = string.format("%s 菜单", L["WOWTHREADS_OPTIONS"])
    L["WOWTHREADS_AND_VERSION"]     = string.format("%s %s (%s)", L["WOWTHREADS_NAME"], L["VERSION"], L["EXPANSION_NAME"])
    L["ADDON_MESSAGE"]              = string.format("%s 已加载。", L["WOWTHREADS_AND_VERSION"])
    L["ERROR_MSG_FRAME_TITLE"]      = string.format("%s 错误信息。", L["WOWTHREADS_AND_VERSION"])

    L["NOTIFICATION_FRAME_TITLE"]   = string.format("通知 - %s", L["WOWTHREADS_VERSION"])
    L["LINE1"] = "    WoWThreads 是一个服务库，使开发人员能够"
    L["LINE2"] = "将非抢占式异步多线程集成到"
    L["LINE3"] = "他们的插件中。您可以阅读更多关于线程编程的一般信息，"
    L["LINE4"] = "尤其是关于 WoWThreads 的信息。请参阅 Docs 子目录中的 WoWThreads-complete.md。"

    L["ACCEPT_BUTTON_LABEL"]    = "接受"
    L["DISMISS_BUTTON_LABEL"]   = "关闭"

    L["ENABLE_DATA_COLLECTION"] = "选中以收集系统开销数据。"
    L["TOOTIP_DATA_COLLECTION"] = "如果选中，将收集每个线程的系统开销。"

    L["ENABLE_ERROR_LOGGING"]   = "选中以启用错误日志记录。"
    L["TOOLTIP_DEBUGGING"]      = "如果选中，将在聊天窗口中写入更多的错误信息。"

    L["WRONG_TYPE"]             = "错误：意外的数据类型"
    L["PARAMETER_NIL"]          = "错误：参数为 nil"

    L["THREAD_HANDLE_NIL"]      = "错误：线程句柄为 nil"
    L["THREAD_HANDLE_WRONG_TYPE"] = "错误：无效的句柄。类型错误。应为 'table' 类型"
    L["THREAD_NO_COROUTINE"]    = "错误：句柄不引用协程"
    L["THREAD_INVALID_CONTEXT"] = "错误：调用者可能是 WoW 客户端（WoW.exe）"
    L["THREAD_HANDLE_ILL_FORMED"] = "错误：线程句柄格式错误。检查表格大小。"

    L["THREAD_COROUTINE_DEAD"]  = "错误：无效的句柄。线程已完成或失败。"
    L["THREAD_NOT_FOUND"]       = "错误：找不到线程。"

    L["SIGNAL_OUT_OF_RANGE"]    = "错误：信号超出范围"
    L["SIGNAL_IS_NIL"]          = "错误：信号未知或为 nil"
    L["SIGNAL_INVALID_TYPE"]    = "错误：信号类型无效。应为 'number'"
    L["SIGNAL_INVALID_OPERATION"] = "错误：SIG_NONE_PENDING 无法发送"
end
if LOCALE == "svSE" then
    L["WOWTHREADS_NAME"]            = ADDON_NAME
    L["VERSION"]                    = version
    L["EXPANSION_NAME"]             = getExpansionName()
    L["WOWTHREADS_VERSION"]         = string.format("%s (%s)", L["WOWTHREADS_NAME"], L["VERSION"])
    L["TICK_INTERVAL"]              = string.format("Klockintervall: %0.3f ms", tickInterval)
    L["WOWTHREADS_OPTIONS"]         = string.format("%s Alternativ", L["WOWTHREADS_NAME"])
    L["WOWTHREADS_OPTIONS_MENU"]    = string.format("%s Meny", L["WOWTHREADS_OPTIONS"])
    L["WOWTHREADS_AND_VERSION"]     = string.format("%s %s (%s)", L["WOWTHREADS_NAME"], L["VERSION"], L["EXPANSION_NAME"])
    L["ADDON_MESSAGE"]              = string.format("%s laddad.", L["WOWTHREADS_AND_VERSION"])
    L["ERROR_MSG_FRAME_TITLE"]      = string.format("%s Felmeddelanden.", L["WOWTHREADS_AND_VERSION"])

    L["NOTIFICATION_FRAME_TITLE"]   = string.format("Notifikationer - %s", L["WOWTHREADS_VERSION"])
    L["LINE1"] = "    WoWThreads är ett bibliotek av tjänster som möjliggör för utvecklare"
    L["LINE2"] = "att integrera asynkron, icke-preemptiv multitrådning i sina"
    L["LINE3"] = "addons. Du kan läsa mer om trådprogrammering i allmänhet,"
    L["LINE4"] = "och WoWThreads i synnerhet. Se, WoWThreads-complete.md i"
    L["LINE5"] = "Docs-undermappen."

    L["ACCEPT_BUTTON_LABEL"]    = "Acceptera"
    L["DISMISS_BUTTON_LABEL"]   = "Avvisa"

    L["ENABLE_DATA_COLLECTION"] = "Kryssa i för att samla in systemöverskottsdata."
    L["TOOTIP_DATA_COLLECTION"] = "Om kryssat, kommer systemöverskott per tråd att samlas in."

    L["ENABLE_ERROR_LOGGING"]   = "Kryssa i för att aktivera felregistrering."
    L["TOOLTIP_DEBUGGING"]      = "Om kryssat, kommer ytterligare felinformation att skrivas till chatfönstret."

    L["WRONG_TYPE"]             = "FEL: Oväntad datatyp"
    L["PARAMETER_NIL"]          = "FEL: Parametern är nil"

    L["THREAD_HANDLE_NIL"]      = "FEL: Trådhandtaget är nil"
    L["THREAD_HANDLE_WRONG_TYPE"] = "FEL: Ogiltigt handtag. Fel typ. Bör vara av typen 'table'"
    L["THREAD_NO_COROUTINE"]    = "FEL: Handtaget refererar inte till en coroutine"
    L["THREAD_INVALID_CONTEXT"] = "FEL: Anroparen är förmodligen WoW-klienten (WoW.exe)"
    L["THREAD_HANDLE_ILL_FORMED"] = "FEL: Trådhandtaget är felaktigt. Kontrollera tabellstorleken."

    L["THREAD_COROUTINE_DEAD"]  = "FEL: Ogiltigt handtag. Tråden har avslutats eller har misslyckats."
    L["THREAD_NOT_FOUND"]       = "FEL: Tråden hittades inte."

    L["SIGNAL_OUT_OF_RANGE"]    = "FEL: Signalen är utanför räckvidd"
    L["SIGNAL_IS_NIL"]          = "FEL: Signalen är okänd eller nil"
    L["SIGNAL_INVALID_TYPE"]    = "FEL: Signaltypen är ogiltig. Bör vara 'number'"
    L["SIGNAL_INVALID_OPERATION"] = "FEL: SIG_NONE_PENDING kan inte skickas"
end
