-- Filename: Locales.lua
WoWThreads = WoWThreads or {}
WoWThreads.Locales = WoWThreads.Locales or {}

if not WoWThreads.Core.loaded then
    DEFAULT_CHAT_FRAME:AddMessage( "Core.lua not Loaded", 1, 0, 0 )
    return
end

local core = WoWThreads.Core
local addonName, addonVersion, addonExpansion = core:getAddonInfo()
-- =====================================================================
--                      LOCALIZATION
-- =====================================================================
local L = setmetatable({}, { __index = function(t, k) 
	local v = tostring(k)
	rawset(t, k, v)
	return v
end })

WoWThreads.Locales.L = L
local LOCALE = GetLocale()
local addonName, addonVersion, addonExpansion = core:getAddonInfo()
local addonLoadedMessage = string.format("%s v%s, %s loaded.", addonName, addonVersion, addonExpansion )

if LOCALE == "enUS" then

    L["ADDON_LOADED_MESSAGE"] = addonLoadedMessage

    --                          Generic Error MessageS
    --                      Minimap Options Menu Localizations
    L["NOTIFICATION_FRAME_TITLE"]   = string.format( "Notifications - %s ",  L["WOWTHREADS_VERSION"])
    L["LINE1"] = "    WoWThreads is a library of services that enable developers"
    L["LINE2"] = "to incorporate asynchronous, non-preemptive multithreading into"
    L["LINE3"] = "their addons. You can read more about thread programming generally,"
    L["LINE4"] = "and WoWThreads specifically. See, WoWThreads-complete.md in the"
    L["LINE5"] = "Docs subdirectory."

    L["ACCEPT_BUTTON_LABEL"]    = "Accept"
    L["DISMISS_BUTTON_LABEL"]   = "Dismiss"

    L["ENABLE_DATA_COLLECTION"] = "Check to enable data collection."
    L["TOOTIP_DATA_COLLECTION"] = "If checked, the system overhead per thread will be collected."

    L["ENABLE_ERROR_LOGGING"]   = "Check to enable debug logs."
    L["TOOLTIP_DEBUGGING"]      = "If checked, writes additional error information to the Chat Window."
	 L["TOOLTIP_DATA_COLLECTION"] = "If checked, the system overhead per thread will be collected."


	--                          Thread-specific messages
	L["INVALID_TYPE"]				= "ERROR: Datatype unexpected "
    L["PARAMETER_NIL"]  			= "ERROR: Parameter nil "
	L["INVALID_OPERATION"]			= "ERROR: Operation not permitted (e.g., invalid state) "
	L["THREAD_HANDLE_NIL"] 		    = "ERROR: Thread handle nil "
	L["THREAD_NO_COROUTINE"]        = "ERROR: Handle does not reference a coroutine "
    L["THREAD_INVALID_CONTEXT"]     = "ERROR: Caller is likely the WoW client (WoW.exe) "
	L["THREAD_HANDLE_ILL_FORMED"]	= "ERROR: Thread handle ill-formed. Check table size. "
    L["THREAD_NOT_COMPLETED"]       = "ERROR: Thread has not yet completed. "

	L["THREAD_COROUTINE_DEAD"]      = "ERROR: Invalid handle. Thread has completed or faulted. "
    L["THREAD_NOT_FOUND"]           = "ERROR: Thread not found. "

    -- Signal failure
	L["SIGNAL_OUT_OF_RANGE"]	    = "ERROR: Signal is out of range "
    L["SIGNAL_IS_NIL"]	            = "ERROR: Signal is unknown or nil "
    L["SIGNAL_INVALID_TYPE"]        = "ERROR: Signal type is invalid. Should be 'number' "
    L["SIGNAL_INVALID_OPERATION"]   = "ERROR: SIG_NONE_PENDING can not be sent "
end
if LOCALE == "deDE" then
    L["ADDON_LOADED_MESSAGE"] = addonLoadedMessage

    L["INVALID_TYPE"]		= "FEHLER: Unerwarteter Datentyp "
    L["PARAMETER_NIL"]  	= "FEHLER: Parameter ist nil "

    L["NOTIFICATION_FRAME_TITLE"]   = string.format("Benachrichtigungen - %s ", L["WOWTHREADS_VERSION"])
    L["LINE1"] = "    WoWThreads ist eine Bibliothek von Diensten, die es Entwicklern ermöglicht,"
    L["LINE2"] = "asynchrones, nicht-preemptives Multithreading in ihre Addons"
    L["LINE3"] = "einzubauen. Du kannst mehr über Thread-Programmierung allgemein"
    L["LINE4"] = "und über WoWThreads speziell lesen. Siehe WoWThreads-complete.md im"
    L["LINE5"] = "Unterordner Docs."

    L["ACCEPT_BUTTON_LABEL"]    = "Akzeptieren"
    L["DISMISS_BUTTON_LABEL"]   = "Schließen"

    L["ENABLE_DATA_COLLECTION"] = "Ankreuzen, um Datensammlung zu aktivieren."
    L["TOOTIP_DATA_COLLECTION"] = "Wenn angekreuzt, wird der System-Overhead pro Thread gesammelt."

    L["ENABLE_ERROR_LOGGING"]   = "Ankreuzen, um Debug-Logs zu aktivieren."
    L["TOOLTIP_DEBUGGING"]      = "Wenn angekreuzt, werden zusätzliche Fehlerinformationen im Chatfenster ausgegeben."
	 L["TOOLTIP_DATA_COLLECTION"] = "Wenn angekreuzt, wird der System-Overhead pro Thread gesammelt."

	L["THREAD_HANDLE_NIL"] 		    = "FEHLER: Thread-Handle ist nil "
	L["THREAD_NO_COROUTINE"]        = "FEHLER: Handle verweist nicht auf eine Coroutine "
    L["THREAD_INVALID_CONTEXT"]     = "FEHLER: Aufrufer ist wahrscheinlich der WoW-Client (WoW.exe) "
	L["THREAD_HANDLE_ILL_FORMED"]	= "FEHLER: Thread-Handle fehlerhaft. Tabellen-Größe prüfen. "
    L["THREAD_NOT_COMPLETED"]       = "FEHLER: Thread ist noch nicht abgeschlossen. "

	L["THREAD_COROUTINE_DEAD"]      = "FEHLER: Ungültiges Handle. Thread wurde abgeschlossen oder ist abgestürzt. "
    L["THREAD_NOT_FOUND"]           = "FEHLER: Thread nicht gefunden. "

	L["SIGNAL_OUT_OF_RANGE"]	    = "FEHLER: Signal außerhalb des Bereichs "
    L["SIGNAL_IS_NIL"]	            = "FEHLER: Signal ist unbekannt oder nil "
    L["SIGNAL_INVALID_TYPE"]        = "FEHLER: Signaltyp ist ungültig. Sollte 'number' sein "
    L["SIGNAL_INVALID_OPERATION"]   = "FEHLER: SIG_NONE_PENDING kann nicht gesendet werden "
end

if LOCALE == "frFR" then
    L["ADDON_LOADED_MESSAGE"] = addonLoadedMessage

    L["INVALID_TYPE"]		= "ERREUR : Type de donnée inattendu "
    L["PARAMETER_NIL"]  	= "ERREUR : Paramètre nil "

    L["NOTIFICATION_FRAME_TITLE"]   = string.format("Notifications - %s ", L["WOWTHREADS_VERSION"])
    L["LINE1"] = "    WoWThreads est une bibliothèque de services qui permet aux développeurs"
    L["LINE2"] = "d’intégrer du multithreading asynchrone et non préemptif dans"
    L["LINE3"] = "leurs addons. Tu peux en lire plus sur la programmation par threads en général,"
    L["LINE4"] = "et sur WoWThreads en particulier. Voir WoWThreads-complete.md dans le"
    L["LINE5"] = "sous-dossier Docs."

    L["ACCEPT_BUTTON_LABEL"]    = "Accepter"
    L["DISMISS_BUTTON_LABEL"]   = "Fermer"

    L["ENABLE_DATA_COLLECTION"] = "Coche pour activer la collecte de données."
    L["TOOTIP_DATA_COLLECTION"] = "Si coché, la surcharge système par thread sera collectée."

    L["ENABLE_ERROR_LOGGING"]   = "Coche pour activer les journaux de débogage."
    L["TOOLTIP_DEBUGGING"]      = "Si coché, affiche des infos d’erreurs supplémentaires dans la fenêtre de chat."
	 L["TOOLTIP_DATA_COLLECTION"] = "Si coché, la surcharge système par thread sera collectée."

	L["THREAD_HANDLE_NIL"] 		    = "ERREUR : Handle de thread nil "
	L["THREAD_NO_COROUTINE"]        = "ERREUR : Le handle ne référence pas de coroutine "
    L["THREAD_INVALID_CONTEXT"]     = "ERREUR : L’appelant est probablement le client WoW (WoW.exe) "
	L["THREAD_HANDLE_ILL_FORMED"]	= "ERREUR : Handle de thread mal formé. Vérifie la taille de la table. "
    L["THREAD_NOT_COMPLETED"]       = "ERREUR : Le thread n’est pas encore terminé. "

	L["THREAD_COROUTINE_DEAD"]      = "ERREUR : Handle invalide. Le thread est terminé ou en erreur. "
    L["THREAD_NOT_FOUND"]           = "ERREUR : Thread introuvable. "

	L["SIGNAL_OUT_OF_RANGE"]	    = "ERREUR : Signal hors limites "
    L["SIGNAL_IS_NIL"]	            = "ERREUR : Signal inconnu ou nil "
    L["SIGNAL_INVALID_TYPE"]        = "ERREUR : Type de signal invalide. Doit être 'number' "
    L["SIGNAL_INVALID_OPERATION"]   = "ERREUR : SIG_NONE_PENDING ne peut pas être envoyé "
end
if LOCALE == "ruRU" then
    L["ADDON_LOADED_MESSAGE"] = addonLoadedMessage

    L["INVALID_TYPE"]		= "ОШИБКА: Неверный тип данных "
    L["PARAMETER_NIL"]  	= "ОШИБКА: Параметр равен nil "

    L["NOTIFICATION_FRAME_TITLE"]   = string.format("Уведомления - %s ", L["WOWTHREADS_VERSION"])
    L["LINE1"] = "    WoWThreads — это библиотека сервисов, которая позволяет разработчикам"
    L["LINE2"] = "добавлять асинхронный, не вытесняющий многопоток в свои аддоны."
    L["LINE3"] = "Ты можешь почитать больше о потоковом программировании в целом,"
    L["LINE4"] = "и о WoWThreads в частности. См. WoWThreads-complete.md в"
    L["LINE5"] = "папке Docs."

    L["ACCEPT_BUTTON_LABEL"]    = "Принять"
    L["DISMISS_BUTTON_LABEL"]   = "Закрыть"

    L["ENABLE_DATA_COLLECTION"] = "Отметь, чтобы включить сбор данных."
    L["TOOTIP_DATA_COLLECTION"] = "Если отмечено, будет собираться системная нагрузка на поток."

    L["ENABLE_ERROR_LOGGING"]   = "Отметь, чтобы включить отладочные логи."
    L["TOOLTIP_DEBUGGING"]      = "Если отмечено, дополнительная информация об ошибках будет выводиться в чат."
	 L["TOOLTIP_DATA_COLLECTION"] = "Если отмечено, будет собираться системная нагрузка на поток."

	L["THREAD_HANDLE_NIL"] 		    = "ОШИБКА: Указатель потока равен nil "
	L["THREAD_NO_COROUTINE"]        = "ОШИБКА: Указатель не ссылается на корутину "
    L["THREAD_INVALID_CONTEXT"]     = "ОШИБКА: Вероятно вызвано клиентом WoW (WoW.exe) "
	L["THREAD_HANDLE_ILL_FORMED"]	= "ОШИБКА: Указатель потока повреждён. Проверь размер таблицы. "
    L["THREAD_NOT_COMPLETED"]       = "ОШИБКА: Поток ещё не завершён. "

	L["THREAD_COROUTINE_DEAD"]      = "ОШИБКА: Неверный указатель. Поток завершён или сломан. "
    L["THREAD_NOT_FOUND"]           = "ОШИБКА: Поток не найден. "

	L["SIGNAL_OUT_OF_RANGE"]	    = "ОШИБКА: Сигнал вне диапазона "
    L["SIGNAL_IS_NIL"]	            = "ОШИБКА: Сигнал неизвестен или равен nil "
    L["SIGNAL_INVALID_TYPE"]        = "ОШИБКА: Неверный тип сигнала. Должен быть 'number' "
    L["SIGNAL_INVALID_OPERATION"]   = "ОШИБКА: SIG_NONE_PENDING нельзя отправить "
end
if LOCALE == "nbNO" then
    L["ADDON_LOADED_MESSAGE"] = addonLoadedMessage

    L["INVALID_TYPE"]		= "FEIL: Uventet datatype "
    L["PARAMETER_NIL"]  	= "FEIL: Parameter er nil "

    L["NOTIFICATION_FRAME_TITLE"]   = string.format("Varsler - %s ", L["WOWTHREADS_VERSION"])
    L["LINE1"] = "    WoWThreads er et bibliotek med tjenester som lar utviklere"
    L["LINE2"] = "bygge inn asynkron, ikke-preemptiv multithreading i"
    L["LINE3"] = "addonene sine. Du kan lese mer om trådprogrammering generelt,"
    L["LINE4"] = "og WoWThreads spesielt. Se WoWThreads-complete.md i"
    L["LINE5"] = "Docs-mappa."

    L["ACCEPT_BUTTON_LABEL"]    = "Godta"
    L["DISMISS_BUTTON_LABEL"]   = "Lukk"

    L["ENABLE_DATA_COLLECTION"] = "Huk av for å slå på datainnsamling."
    L["TOOTIP_DATA_COLLECTION"] = "Hvis huket av, vil systemoverhead per tråd bli samlet."

    L["ENABLE_ERROR_LOGGING"]   = "Huk av for å slå på feillogger."
    L["TOOLTIP_DEBUGGING"]      = "Hvis huket av, skrives ekstra feilmeldinger til chatvinduet."
	 L["TOOLTIP_DATA_COLLECTION"] = "Hvis huket av, vil systemoverhead per tråd bli samlet."

	L["THREAD_HANDLE_NIL"] 		    = "FEIL: Tråd-handle er nil "
	L["THREAD_NO_COROUTINE"]        = "FEIL: Handle peker ikke på en coroutine "
    L["THREAD_INVALID_CONTEXT"]     = "FEIL: Kallet kommer sannsynligvis fra WoW-klienten (WoW.exe) "
	L["THREAD_HANDLE_ILL_FORMED"]	= "FEIL: Tråd-handle er ugyldig. Sjekk tabellstørrelsen. "
    L["THREAD_NOT_COMPLETED"]       = "FEIL: Tråden er ikke ferdig enda. "

	L["THREAD_COROUTINE_DEAD"]      = "FEIL: Ugyldig handle. Tråden er ferdig eller krasjet. "
    L["THREAD_NOT_FOUND"]           = "FEIL: Fant ikke tråd. "

	L["SIGNAL_OUT_OF_RANGE"]	    = "FEIL: Signal utenfor rekkevidde "
    L["SIGNAL_IS_NIL"]	            = "FEIL: Signal er ukjent eller nil "
    L["SIGNAL_INVALID_TYPE"]        = "FEIL: Signaltypen er ugyldig. Skal være 'number' "
    L["SIGNAL_INVALID_OPERATION"]   = "FEIL: SIG_NONE_PENDING kan ikke sendes "
end
if LOCALE == "jaJP" then
    L["ADDON_LOADED_MESSAGE"] = addonLoadedMessage

    L["INVALID_TYPE"]		= "エラー: 想定外のデータ型 "
    L["PARAMETER_NIL"]  	= "エラー: パラメータが nil です "

    L["NOTIFICATION_FRAME_TITLE"]   = string.format("通知 - %s ", L["WOWTHREADS_VERSION"])
    L["LINE1"] = "    WoWThreads は開発者がアドオンに"
    L["LINE2"] = "非プリエンプティブな非同期マルチスレッドを組み込めるようにする"
    L["LINE3"] = "サービスライブラリです。スレッドプログラミング全般や、"
    L["LINE4"] = "WoWThreads について詳しくは Docs フォルダ内の"
    L["LINE5"] = "WoWThreads-complete.md を見てください。"

    L["ACCEPT_BUTTON_LABEL"]    = "承認"
    L["DISMISS_BUTTON_LABEL"]   = "閉じる"

    L["ENABLE_DATA_COLLECTION"] = "チェックするとデータ収集を有効にします。"
    L["TOOTIP_DATA_COLLECTION"] = "チェックすると、スレッドごとのシステムオーバーヘッドが収集されます。"

    L["ENABLE_ERROR_LOGGING"]   = "チェックするとデバッグログを有効にします。"
    L["TOOLTIP_DEBUGGING"]      = "チェックすると、追加のエラー情報がチャットウィンドウに表示されます。"
	 L["TOOLTIP_DATA_COLLECTION"] = "チェックすると、スレッドごとのシステムオーバーヘッドが収集されます。"

	L["THREAD_HANDLE_NIL"] 		    = "エラー: スレッドハンドルが nil です "
	L["THREAD_NO_COROUTINE"]        = "エラー: ハンドルがコルーチンを参照していません "
    L["THREAD_INVALID_CONTEXT"]     = "エラー: 呼び出し元は WoW クライアント (WoW.exe) の可能性があります "
	L["THREAD_HANDLE_ILL_FORMED"]	= "エラー: スレッドハンドルの形式が不正です。テーブルサイズを確認してください。 "
    L["THREAD_NOT_COMPLETED"]       = "エラー: スレッドはまだ完了していません。 "

	L["THREAD_COROUTINE_DEAD"]      = "エラー: 無効なハンドルです。スレッドは終了したかエラーになりました。 "
    L["THREAD_NOT_FOUND"]           = "エラー: スレッドが見つかりません。 "

	L["SIGNAL_OUT_OF_RANGE"]	    = "エラー: シグナルが範囲外です "
    L["SIGNAL_IS_NIL"]	            = "エラー: シグナルが不明または nil です "
    L["SIGNAL_INVALID_TYPE"]        = "エラー: シグナルの型が不正です。'number' である必要があります "
    L["SIGNAL_INVALID_OPERATION"]   = "エラー: SIG_NONE_PENDING は送信できません "
end
if LOCALE == "zhCN" then
    L["ADDON_LOADED_MESSAGE"] = addonLoadedMessage

    L["INVALID_TYPE"]		= "错误：数据类型不符合预期 "
    L["PARAMETER_NIL"]  	= "错误：参数为 nil "

    L["NOTIFICATION_FRAME_TITLE"]   = string.format("通知 - %s ", L["WOWTHREADS_VERSION"])
    L["LINE1"] = "    WoWThreads 是一个服务库，让开发者可以在插件中"
    L["LINE2"] = "加入异步、非抢占式的多线程功能。"
    L["LINE3"] = "你可以阅读更多关于线程编程的一般知识，"
    L["LINE4"] = "以及关于 WoWThreads 的详细说明。请查看 Docs 文件夹中的"
    L["LINE5"] = "WoWThreads-complete.md。"

    L["ACCEPT_BUTTON_LABEL"]    = "接受"
    L["DISMISS_BUTTON_LABEL"]   = "关闭"

    L["ENABLE_DATA_COLLECTION"] = "勾选以启用数据收集。"
    L["TOOTIP_DATA_COLLECTION"] = "如果勾选，将收集每个线程的系统开销。"

    L["ENABLE_ERROR_LOGGING"]   = "勾选以启用调试日志。"
    L["TOOLTIP_DEBUGGING"]      = "如果勾选，会在聊天窗口中显示更多错误信息。"
	 L["TOOLTIP_DATA_COLLECTION"] = "如果勾选，将收集每个线程的系统开销。"

	L["THREAD_HANDLE_NIL"] 		    = "错误：线程句柄为 nil "
	L["THREAD_NO_COROUTINE"]        = "错误：句柄没有指向协程 "
    L["THREAD_INVALID_CONTEXT"]     = "错误：调用者可能是 WoW 客户端 (WoW.exe) "
	L["THREAD_HANDLE_ILL_FORMED"]	= "错误：线程句柄格式错误。请检查表大小。 "
    L["THREAD_NOT_COMPLETED"]       = "错误：线程尚未完成。 "

	L["THREAD_COROUTINE_DEAD"]      = "错误：无效句柄。线程已结束或出错。 "
    L["THREAD_NOT_FOUND"]           = "错误：未找到线程。 "

	L["SIGNAL_OUT_OF_RANGE"]	    = "错误：信号超出范围 "
    L["SIGNAL_IS_NIL"]	            = "错误：信号未知或为 nil "
    L["SIGNAL_INVALID_TYPE"]        = "错误：信号类型无效。必须是 'number' "
    L["SIGNAL_INVALID_OPERATION"]   = "错误：不能发送 SIG_NONE_PENDING "
end
if LOCALE == "esES" then
    L["ADDON_LOADED_MESSAGE"] = addonLoadedMessage

    L["INVALID_TYPE"]		= "ERROR: Tipo de dato inesperado "
    L["PARAMETER_NIL"]  	= "ERROR: El parámetro es nil "

    L["NOTIFICATION_FRAME_TITLE"]   = string.format("Notificaciones - %s ", L["WOWTHREADS_VERSION"])
    L["LINE1"] = "    WoWThreads es una librería de servicios que permite a los desarrolladores"
    L["LINE2"] = "incorporar multihilo asíncrono y no preventivo en"
    L["LINE3"] = "sus addons. Puedes leer más sobre programación con hilos en general,"
    L["LINE4"] = "y sobre WoWThreads en particular. Mira WoWThreads-complete.md en la"
    L["LINE5"] = "carpeta Docs."

    L["ACCEPT_BUTTON_LABEL"]    = "Aceptar"
    L["DISMISS_BUTTON_LABEL"]   = "Cerrar"

    L["ENABLE_DATA_COLLECTION"] = "Marca para activar la recolección de datos."
    L["TOOTIP_DATA_COLLECTION"] = "Si está marcado, se recogerá la sobrecarga del sistema por cada hilo."

    L["ENABLE_ERROR_LOGGING"]   = "Marca para activar los registros de depuración."
    L["TOOLTIP_DEBUGGING"]      = "Si está marcado, se mostrarán más detalles de errores en la ventana de chat."
	 L["TOOLTIP_DATA_COLLECTION"] = "Si está marcado, se recogerá la sobrecarga del sistema por cada hilo."

	L["THREAD_HANDLE_NIL"] 		    = "ERROR: El handle del hilo es nil "
	L["THREAD_NO_COROUTINE"]        = "ERROR: El handle no hace referencia a una coroutine "
    L["THREAD_INVALID_CONTEXT"]     = "ERROR: Probablemente fue llamado por el cliente de WoW (WoW.exe) "
	L["THREAD_HANDLE_ILL_FORMED"]	= "ERROR: Handle del hilo mal formado. Revisa el tamaño de la tabla. "
    L["THREAD_NOT_COMPLETED"]       = "ERROR: El hilo aún no ha terminado. "

	L["THREAD_COROUTINE_DEAD"]      = "ERROR: Handle inválido. El hilo terminó o falló. "
    L["THREAD_NOT_FOUND"]           = "ERROR: Hilo no encontrado. "

	L["SIGNAL_OUT_OF_RANGE"]	    = "ERROR: Señal fuera de rango "
    L["SIGNAL_IS_NIL"]	            = "ERROR: Señal desconocida o nil "
    L["SIGNAL_INVALID_TYPE"]        = "ERROR: Tipo de señal inválido. Debe ser 'number' "
    L["SIGNAL_INVALID_OPERATION"]   = "ERROR: No se puede enviar SIG_NONE_PENDING "
end
if LOCALE == "tlh" then
    L["ADDON_LOADED_MESSAGE"] = addonLoadedMessage

    L["INVALID_TYPE"]		= "Qagh: De' mI' 'oHbe' "
    L["PARAMETER_NIL"]  	= "Qagh: patlh pagh (nil) "

    L["NOTIFICATION_FRAME_TITLE"]   = string.format("Dochmey QIn - %s ", L["WOWTHREADS_VERSION"])
    L["LINE1"] = "    WoWThreads 'oH Qu'mey ra'meH paq'e'."
    L["LINE2"] = "lo'laH qejwI'pu' 'ej lInglaH latlh De'wI'mey."
    L["LINE3"] = "tugh SoH laDlaH 'e' maq ghantoHmey patmey,"
    L["LINE4"] = "WoWThreads 'angchu'. yIlegh WoWThreads-complete.md"
    L["LINE5"] = "Docs pa' ghom."

    L["ACCEPT_BUTTON_LABEL"]    = "HIja’"
    L["DISMISS_BUTTON_LABEL"]   = "yImej"

    L["ENABLE_DATA_COLLECTION"] = "yIqaw! De' bo'vam chu'."
    L["TOOTIP_DATA_COLLECTION"] = "vaj chu', wa' DoS ghap patlh De'wI' SoQ tu'lu'."

    L["ENABLE_ERROR_LOGGING"]   = "yIqaw! Qagh log chu'."
    L["TOOLTIP_DEBUGGING"]      = "vaj chu', De' qagh latlh ghItlh De'wI' SoQDaq."
	 L["TOOLTIP_DATA_COLLECTION"] = "vaj chu', wa' DoS ghap patlh De'wI' SoQ tu'lu'."

	L["THREAD_HANDLE_NIL"] 		    = "Qagh: qej Degh pagh (nil) "
	L["THREAD_NO_COROUTINE"]        = "Qagh: Degh qej qelHa’ "
    L["THREAD_INVALID_CONTEXT"]     = "Qagh: ghaytan WoW.exe ghaH QelwI' "
	L["THREAD_HANDLE_ILL_FORMED"]	= "Qagh: qej Degh lughHa'. ghItlh'a' tIn yISam. "
    L["THREAD_NOT_COMPLETED"]       = "Qagh: qej ta' rInbe'. "

	L["THREAD_COROUTINE_DEAD"]      = "Qagh: Degh lughHa'. qej rInpu’ pagh Qaghpu’. "
    L["THREAD_NOT_FOUND"]           = "Qagh: qej tu’lu’be’. "

	L["SIGNAL_OUT_OF_RANGE"]	    = "Qagh: ghantoH Doch Dung "
    L["SIGNAL_IS_NIL"]	            = "Qagh: ghantoH Sovbe’ pagh nil "
    L["SIGNAL_INVALID_TYPE"]        = "Qagh: ghantoH Segh lughHa’. mI’ neH "
    L["SIGNAL_INVALID_OPERATION"]   = "Qagh: SIG_NONE_PENDING ngeHlaHbe’ "
end

WoWThreads.Locales.loaded = true