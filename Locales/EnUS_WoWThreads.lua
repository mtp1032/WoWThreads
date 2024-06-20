-- Filename: EnUs_WoWThreads.lua
local ADDON_NAME, _ = ...

-- get the uitls library
local UtilsLib = LibStub("UtilsLib")
if not UtilsLib then 
    return 
end
local utils = UtilsLib

-- Create a new library instance, or get the existing one
local LibStub = LibStub
local LIBSTUB_MAJOR, LIBSTUB_MINOR = "EnUSlib", 1
local LibStub = LibStub -- If LibStub is not global, adjust accordingly
local EnUSlib, oldVersion = LibStub:NewLibrary(LIBSTUB_MAJOR, LIBSTUB_MINOR)
if not EnUSlib then 
    return 
end

local expansionName = utils:getExpansionName()
local version = utils:getVersion()

local clockInterval = 1000 / GetFramerate()
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
    -- minimap localizations
    L["OPTIONS"] = string.format("%s Options", ADDON_NAME )
    L["OPTIONS_MENUS"]= string.format("%s %s", L["OPTIONS"], "Menu")

    L["LINE1"] = "    WoWThreads is a library of services that enable developers"
    L["LINE2"] = "to incorporate asynchronous, non-preemptive multithreading into"
    L["LINE3"] = "their addons. You can read more about thread programming generally"
    L["LINE4"] = "and WoWThreads specifically in the Docs directory."

    L["ACCEPT_BUTTON_LABEL"]    = "Accept"
    L["DISMISS_BUTTON_LABEL"]   = "Dismiss"

    L["ENABLE_DATA_COLLECTION"] = "Check to collect thread congestion data."
    L["TOOTIP_DATA_COLLECTION"] = "If checked, per thread congestion data will be collected."

    L["TOOLTIP_DEBUGGING"]      = "If checked, most errors are not returned to the calling thread. Instead, the thread fails in place and generates an error message and a stack trace."


	-- WoWThreads Localizations
    L["CLOCK_INTERVAL"]     = string.format("Clock Interval: %0.3f ms", clockInterval )
	L["VERSION"] 			= version
	L["ADDON_MESSAGE"]		= string.format("%s (%s) loaded ",  "WoWThreads-1.0", expansionName )
    L["ERROR_MSG_FRAME_TITLE"] = "Error Messages - WoWThreads-1.0"
 	-- Generic Error MessageS
    L["INVALID_TYPE"]		= "ERROR: Input parameter nil  "
	L["INVALID_TYPE"]		= "ERROR: Input datatype invalid "
    L["INPUT_PARM_NIL"]     = "ERROR: Input parameter nil "

	-- Thread specific messages
	L["THREAD_HANDLE_NIL"] 		= "ERROR: Thread handle nil "
    L["THREAD_HANDLE_INVALID"]         = "ERROR: Invalid handle "
	L["THREAD_INVALID_STATE"]	    = "ERROR: Thread[%d] is %s "
	L["HANDLE_ILL_FORMED"]	    = "ERROR: Thread handle ill-formed "
	L["NOT_A_THREAD"]           = "ERROR: Specified Thread handle does not reference a coroutine "
    L["THREAD_INVALID_CONTEXT"]      = "ERROR: Caller is likely the WoW client (WoW.exe) "
    L["HANDLE_NOT_SPECIFIED"]   = "ERROR: Handle not specified "
    L["THREAD_CREATE_FAILED"]   = "Failed to create thread "
    L["HANDLE_NON_EXISTANT"]      = "Failed: Handle does not exist. "

	L["INVALID_EXE_CONTEXT"]    = "ERROR: Operation requires thread context "
	L["THREAD_IS_DEAD"]	        = "ERROR: Invalid handle. Thread has completed or faulted. "
    
    L["RESUME_FAILED"]          = "Failed to resume thread "
    L["THREAD_NOT_FOUND"]       = "Thread not found. "
   
    L["THREAD_ALREADY_SLEEPING"]        = "Specified thread already sleeping. "
    L["THREAD_NOT_SLEEPING"]    = "Specified thread not sleeping. "
    L["THREAD_SLEEP_FAILED"]    = "Attempt to put thread to sleep failed. "
    L["WRONG_ADDON_NAME"]       = "Wrong Addon Name"
	
	L["SIGNAL_QUEUE_INVALID"]	= "ERROR: Thread[%d] Invalid signal queue "
    L["SIGNAL_QUEUE_EMPTY"]     = "ERROR: Signal queue is empty "
	L["SIGNAL_OUT_OF_RANGE"]	= "ERROR: Signal is out of range "
    L["SIGNAL_INVALID"]			= "ERROR: Signal is unknown or nil "
    L["SIGNAL_INVALID_OPERATION"] = "ERROR: SIG_NONE_PENDING can not be sent "
    L["SIGNAL_NOT_DELIVERED"]   = "ERROR: Signal not delivered "
    L["SIGNAL_PARAMETER"]       = "ERROR: Too many signal parameters "
    L["SIGNAL_INVALID_NAME"]    = "ERROR: Invalid signal name, %s "
end
if LOCALE == "frFR" then
	-- WoWThreads Localizations
	L["VERSION"]             = version
	L["ADDON_MESSAGE"]       = string.format("%s (%s) chargé ", libraryName, expansionName)

	-- Generic Error Messages
	L["INPUT_PARM_NIL"]      = "[ERREUR] Paramètre d'entrée nil "
	L["INVALID_TYPE"]        = "[ERREUR] Type de données d'entrée invalide. Attendu %s "

	-- Thread specific messages
	L["THREAD_HANDLE_NIL"]     = "[ERREUR] Descripteur de thread nil "
	L["THREAD_INVALID_STATE"]   = "[ERREUR] Thread[%d] est %s "
	L["HANDLE_ILL_FORMED"]   = "[ERREUR] Descripteur de thread mal formé "
	L["NOT_A_THREAD"] = "[ERREUR] Le descripteur spécifié ne référence pas une coroutine "

	L["INVALID_EXE_CONTEXT"] = "[ERREUR] Opération nécessite un contexte de thread "
	L["THREAD_IS_DEAD"]      = "[ERREUR] Descripteur invalide. Le descripteur est probablement 'mort.' "
	L["RESUME_FAILED"]       = "[ERREUR] Échec de la reprise du thread[%d]: "

	L["SIGNAL_QUEUE_INVALID"] = "[ERREUR] Thread[%d] File d'attente de signaux invalide "
	L["SIGNAL_OUT_OF_RANGE"]  = "[ERREUR] Signal hors de portée "
	L["SIGNAL_INVALID"]       = "[ERREUR] Signal inconnu "
end
if LOCALE == "deDE" then

    -- WoWThreads Lokalisierungen
    L["VERSION"]              = version
    L["ADDON_MESSAGE"]        = string.format("%s (%s) geladen ", libraryName, expansionName )

    -- Allgemeine Fehlermeldungen
    L["INPUT_PARM_NIL"]       = "[FEHLER] Eingabeparameter nil "
    L["INVALID_TYPE"]         = "[FEHLER] Eingabedatentyp ungültig. Erwartet wurde %s "

    -- Thread-spezifische Nachrichten
    L["THREAD_HANDLE_NIL"]           = "[FEHLER] Thread-Handle nil "
    L["THREAD_INVALID_STATE"]    = "[FEHLER] Thread[%d] ist %s "
    L["HANDLE_ILL_FORMED"]    = "[FEHLER] Thread-Handle fehlerhaft "
    L["NOT_A_THREAD"]  = "[FEHLER] Angegebenes Thread-Handle ist keine Coroutine "

    L["INVALID_EXE_CONTEXT"]  = "[FEHLER] Operation erfordert Thread-Kontext "
    L["THREAD_IS_DEAD"]       = "[FEHLER] Ungültiges Handle. Handle ist wahrscheinlich 'tot' "
    L["RESUME_FAILED"]        = "[FEHLER] Fortsetzung von Thread[%d] fehlgeschlagen: "
    
    L["SIGNAL_QUEUE_INVALID"] = "[FEHLER] Thread[%d] Ungültige Signalwarteschlange "
    L["SIGNAL_OUT_OF_RANGE"]  = "[FEHLER] Signal liegt außerhalb des gültigen Bereichs "
    L["SIGNAL_INVALID"]       = "[FEHLER] Signal ist unbekannt "
end
if LOCALE == "frFR" then

    -- Localisations pour WoWThreads
    L["VERSION"]              = version
    L["ADDON_MESSAGE"]        = string.format("%s (%s) chargé ", libraryName, expansionName )

    -- Messages d'erreur génériques
    L["INPUT_PARM_NIL"]       = "[ERREUR] Paramètre d'entrée nul "
    L["INVALID_TYPE"]         = "[ERREUR] Type de données d'entrée invalide. Attendu %s "

    -- Messages spécifiques aux threads
    L["THREAD_HANDLE_NIL"]           = "[ERREUR] Descripteur de thread nul "
    L["THREAD_INVALID_STATE"]    = "[ERREUR] Thread[%d] est %s "
    L["HANDLE_ILL_FORMED"]    = "[ERREUR] Descripteur de thread mal formé "
    L["NOT_A_THREAD"]  = "[ERREUR] Le descripteur de thread spécifié ne référence pas une coroutine "

    L["INVALID_EXE_CONTEXT"]  = "[ERREUR] L'opération nécessite un contexte de thread "
    L["THREAD_IS_DEAD"]       = "[ERREUR] Descripteur invalide. Le descripteur est probablement 'mort' "
    L["RESUME_FAILED"]        = "[ERREUR] Échec de la reprise du thread[%d] : "
    
    L["SIGNAL_QUEUE_INVALID"] = "[ERREUR] Thread[%d] Queue de signal invalide "
    L["SIGNAL_OUT_OF_RANGE"]  = "[ERREUR] Signal hors de portée "
    L["SIGNAL_INVALID"]       = "[ERREUR] Signal inconnu "
end
if LOCALE == "zhCN" then

    -- WoWThreads 本地化
    L["VERSION"]              = version
    L["ADDON_MESSAGE"]        = string.format("%s (%s) 已加载。", libraryName, expansionName )

    -- 通用错误消息
    L["INPUT_PARM_NIL"]       = "[错误] 输入参数为空。"
    L["INVALID_TYPE"]         = "[错误] 输入数据类型无效。期望 %s "

    -- 线程特定消息
    L["THREAD_HANDLE_NIL"]           = "[错误] 线程句柄为空。"
    L["THREAD_INVALID_STATE"]    = "[错误] 线程[%d]为%s。"
    L["HANDLE_ILL_FORMED"]    = "[错误] 线程句柄格式错误。"
    L["NOT_A_THREAD"]  = "[错误] 指定的线程句柄不引用协程。"

    L["INVALID_EXE_CONTEXT"]  = "[错误] 操作需要线程上下文。"
    L["THREAD_IS_DEAD"]       = "[错误] 句柄无效。句柄可能已经‘死亡’。"
    L["RESUME_FAILED"]        = "[错误] 无法恢复线程[%d]："
    
    L["SIGNAL_QUEUE_INVALID"] = "[错误] 线程[%d]信号队列无效。"
    L["SIGNAL_OUT_OF_RANGE"]  = "[错误] 信号超出范围。"
    L["SIGNAL_INVALID"]       = "[错误] 信号未知。"
end
if LOCALE == "koKR" then

    -- WoWThreads 지역화
    L["VERSION"]              = version
    L["ADDON_MESSAGE"]        = string.format("%s (%s) 로드됨 ", libraryName, expansionName )

    -- 일반 오류 메시지
    L["INPUT_PARM_NIL"]       = "[오류] 입력 매개변수가 nil입니다 "
    L["INVALID_TYPE"]         = "[오류] 입력 데이터 유형이 잘못되었습니다. %s 이(가) 필요합니다 "

    -- 스레드 특정 메시지
    L["THREAD_HANDLE_NIL"]           = "[오류] 스레드 핸들이 nil입니다 "
    L["THREAD_INVALID_STATE"]    = "[오류] 스레드[%d] 상태가 %s입니다 "
    L["HANDLE_ILL_FORMED"]    = "[오류] 스레드 핸들 형식이 잘못되었습니다 "
    L["NOT_A_THREAD"]  = "[오류] 지정된 스레드 핸들이 코루틴을 참조하지 않습니다 "

    L["INVALID_EXE_CONTEXT"]  = "[오류] 작업에 스레드 컨텍스트가 필요합니다 "
    L["THREAD_IS_DEAD"]       = "[오류] 핸들이 유효하지 않습니다. 핸들은 '죽었을' 가능성이 높습니다 "
    L["RESUME_FAILED"]        = "[오류] 스레드[%d] 재개 실패: "
    
    L["SIGNAL_QUEUE_INVALID"] = "[오류] 스레드[%d] 신호 큐가 유효하지 않습니다 "
    L["SIGNAL_OUT_OF_RANGE"]  = "[오류] 신호가 범위를 벗어났습니다 "
    L["SIGNAL_INVALID"]       = "[오류] 알 수 없는 신호입니다 "
end
if LOCALE == "svSE" then

    -- WoWThreads Lokaliseringar
    L["VERSION"]              = version
    L["ADDON_MESSAGE"]        = string.format("%s (%s) laddat ", libraryName, expansionName )

    -- Generella felmeddelanden
    L["INPUT_PARM_NIL"]       = "[FEL] Inmatningsparameter är null "
    L["INVALID_TYPE"]         = "[FEL] Ogiltig datatyp för inmatning. Förväntad %s "

    -- Trådspecifika meddelanden
    L["THREAD_HANDLE_NIL"]           = "[FEL] Trådhandtag är null "
    L["THREAD_INVALID_STATE"]    = "[FEL] Tråd[%d] är %s "
    L["HANDLE_ILL_FORMED"]    = "[FEL] Trådhandtaget är felaktigt formaterat "
    L["NOT_A_THREAD"]  = "[FEL] Angivet trådhandtag refererar inte till en korutin "

    L["INVALID_EXE_CONTEXT"]  = "[FEL] Operation kräver trådkontext "
    L["THREAD_IS_DEAD"]       = "[FEL] Ogiltigt handtag. Handtaget är troligen 'dött.' "
    L["RESUME_FAILED"]        = "[FEL] Misslyckades med att återuppta tråd[%d]: "
    
    L["SIGNAL_QUEUE_INVALID"] = "[FEL] Tråd[%d] Ogiltig signal kö "
    L["SIGNAL_OUT_OF_RANGE"]  = "[FEL] Signalen är utanför tillåtet intervall "
    L["SIGNAL_INVALID"]       = "[FEL] Signalen är okänd "
end
if LOCALE == "heIL" then

    -- תרגומים ל-WoWThreads
    L["VERSION"]              = version
    L["ADDON_MESSAGE"]        = string.format("%s (%s) נטען ", libraryName, expansionName )

    -- הודעות שגיאה כלליות
    L["INPUT_PARM_NIL"]       = "[שגיאה] פרמטר קלט ריק "
    L["INVALID_TYPE"]         = "[שגיאה] סוג נתוני קלט לא תקין. צפוי %s "

    -- הודעות ספציפיות לתהליכון
    L["THREAD_HANDLE_NIL"]           = "[שגיאה] ידית התהליכון ריקה "
    L["THREAD_INVALID_STATE"]    = "[שגיאה] תהליכון[%d] הוא %s "
    L["HANDLE_ILL_FORMED"]    = "[שגיאה] ידית תהליכון בעייתית "
    L["NOT_A_THREAD"]  = "[שגיאה] ידית התהליכון המצוינת אינה מתייחסת לשגרת הרצה "

    L["INVALID_EXE_CONTEXT"]  = "[שגיאה] הפעולה דורשת הקשר של תהליכון "
    L["THREAD_IS_DEAD"]       = "[שגיאה] ידית לא תקינה. יש סבירות שהידית 'מתה.' "
    L["RESUME_FAILED"]        = "[שגיאה] נכשל בחידוש התהליכון[%d]: "
    
    L["SIGNAL_QUEUE_INVALID"] = "[שגיאה] תהליכון[%d] תור אותות לא תקין "
    L["SIGNAL_OUT_OF_RANGE"]  = "[שגיאה] האות נמצא מחוץ לטווח "
    L["SIGNAL_INVALID"]       = "[שגיאה] האות אינו מוכר "
end
if LOCALE == "esES" then
    -- Localizaciones de WoWThreads
    L["VERSION"]              = version
    L["ADDON_MESSAGE"]        = string.format("%s (%s) cargado ", libraryName, expansionName )

    -- Mensajes de Error Genéricos
    L["INPUT_PARM_NIL"]       = "ERROR: Parámetro de entrada nulo "
    L["INVALID_TYPE"]         = "ERROR: Tipo de dato de entrada inválido. Se esperaba %s "

    -- Mensajes específicos de hilos
    L["THREAD_HANDLE_NIL"]           = "ERROR: Identificador del hilo nulo "
    L["THREAD_INVALID_STATE"]    = "ERROR: Hilo[%d] está %s "
    L["HANDLE_ILL_FORMED"]    = "ERROR: Identificador del hilo mal formado "
    L["NOT_A_THREAD"]  = "ERROR: El identificador de hilo especificado no hace referencia a una coroutina "

    L["INVALID_EXE_CONTEXT"]  = "ERROR: La operación requiere contexto de hilo "
    L["THREAD_IS_DEAD"]       = "ERROR: Identificador inválido. El identificador probablemente esté 'muerto' "
    L["RESUME_FAILED"]        = "ERROR: Fallo al reanudar el hilo[%d]: "
    
    L["SIGNAL_QUEUE_INVALID"] = "ERROR: Hilo[%d] Cola de señales inválida "
    L["SIGNAL_OUT_OF_RANGE"]  = "ERROR: Señal fuera de rango "
    L["SIGNAL_INVALID"]       = "ERROR: Señal desconocida "
end

local fileName = "EnUS_WoWThreads.lua" 
if utils:debuggingIsEnabled() then
    DEFAULT_CHAT_FRAME:AddMessage( fileName, 0.0, 1.0, 1.0 )
end
