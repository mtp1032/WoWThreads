-- Filename: EnUs_WoWThreads.lua
local ADDON_NAME, _ = ...
local fileName = "EnUS_WoWThreads.lua"
local sprintf = _G.string.format

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

local clockInterval = 1 / GetFramerate() * 1000
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

	-- WoWThreads Localizations
    L["CLOCK_INTERVAL"]     = sprintf("Clock Interval: %0.3f ms", clockInterval )
	L["VERSION"] 			= version
	L["ADDON_MESSAGE"]		= sprintf("%s (%s) loaded. ",  "WoWThreads-1.0", expansionName )
    L["ERROR_MSG_FRAME_TITLE"] = "Error Messages - WoWThreads-1.0"
 	-- Generic Error MessageS
	L["INPUT_PARM_NIL"]		= "%s ERROR: Input parameter nil. "
	L["INVALID_TYPE"]		= "%s ERROR: Input datatype invalid, %s. Expected %s."

	-- Thread specific messages
	L["HANDLE_NIL"] 		= "%s ERROR: Thread handle nil. "
	L["INVALID_EXE_STATE"]	= "%s ERROR: Thread[%d] is %s. "
	L["HANDLE_ILL_FORMED"]	= "%s ERROR: Thread handle ill-formed."
	L["HANDLE_NOT_A_THREAD"] = "%s ERROR: Specified Thread handle does not reference a coroutine."

	L["INVALID_EXE_CONTEXT"] = "%s ERROR: Operation requires thread context. "
	L["HANDLE_INVALID"]		= "%s ERROR: Invalid handle. Handle is likely 'dead.' "
    L["RESUME_FAILED"]      = "%s ERROR: Failed to resume thread[%d]: "
	
	L["SIGNAL_QUEUE_INVALID"]	= "%s ERROR: Thread[%d] Invalid signal queue. "
	L["SIGNAL_OUT_OF_RANGE"]	= "%s ERROR: Signal is out of range. "
    L["SIGNAL_INVALID"]			= "%s ERROR: Signal is unknown."
end
if LOCALE == "frFR" then
	-- WoWThreads Localizations
	L["VERSION"]             = version
	L["ADDON_MESSAGE"]       = sprintf("%s (%s) chargé. ", libraryName, expansionName)

	-- Generic Error Messages
	L["INPUT_PARM_NIL"]      = "[ERREUR] Paramètre d'entrée nil. "
	L["INVALID_TYPE"]        = "[ERREUR] Type de données d'entrée invalide. Attendu %s "

	-- Thread specific messages
	L["HANDLE_NIL"]          = "[ERREUR] Descripteur de thread nil. "
	L["INVALID_EXE_STATE"]   = "[ERREUR] Thread[%d] est %s. "
	L["HANDLE_ILL_FORMED"]   = "[ERREUR] Descripteur de thread mal formé."
	L["HANDLE_NOT_A_THREAD"] = "[ERREUR] Le descripteur spécifié ne référence pas une coroutine."

	L["INVALID_EXE_CONTEXT"] = "[ERREUR] Opération nécessite un contexte de thread. "
	L["HANDLE_INVALID"]      = "[ERREUR] Descripteur invalide. Le descripteur est probablement 'mort.' "
	L["RESUME_FAILED"]       = "[ERREUR] Échec de la reprise du thread[%d]: "

	L["SIGNAL_QUEUE_INVALID"] = "[ERREUR] Thread[%d] File d'attente de signaux invalide. "
	L["SIGNAL_OUT_OF_RANGE"]  = "[ERREUR] Signal hors de portée. "
	L["SIGNAL_INVALID"]       = "[ERREUR] Signal inconnu."
end
if LOCALE == "deDE" then

    -- WoWThreads Lokalisierungen
    L["VERSION"]              = version
    L["ADDON_MESSAGE"]        = sprintf("%s (%s) geladen. ", libraryName, expansionName )

    -- Allgemeine Fehlermeldungen
    L["INPUT_PARM_NIL"]       = "[FEHLER] Eingabeparameter nil. "
    L["INVALID_TYPE"]         = "[FEHLER] Eingabedatentyp ungültig. Erwartet wurde %s "

    -- Thread-spezifische Nachrichten
    L["HANDLE_NIL"]           = "[FEHLER] Thread-Handle nil. "
    L["INVALID_EXE_STATE"]    = "[FEHLER] Thread[%d] ist %s. "
    L["HANDLE_ILL_FORMED"]    = "[FEHLER] Thread-Handle fehlerhaft."
    L["HANDLE_NOT_A_THREAD"]  = "[FEHLER] Angegebenes Thread-Handle ist keine Coroutine."

    L["INVALID_EXE_CONTEXT"]  = "[FEHLER] Operation erfordert Thread-Kontext. "
    L["HANDLE_INVALID"]       = "[FEHLER] Ungültiges Handle. Handle ist wahrscheinlich 'tot'. "
    L["RESUME_FAILED"]        = "[FEHLER] Fortsetzung von Thread[%d] fehlgeschlagen: "
    
    L["SIGNAL_QUEUE_INVALID"] = "[FEHLER] Thread[%d] Ungültige Signalwarteschlange. "
    L["SIGNAL_OUT_OF_RANGE"]  = "[FEHLER] Signal liegt außerhalb des gültigen Bereichs. "
    L["SIGNAL_INVALID"]       = "[FEHLER] Signal ist unbekannt."
end
if LOCALE == "frFR" then

    -- Localisations pour WoWThreads
    L["VERSION"]              = version
    L["ADDON_MESSAGE"]        = sprintf("%s (%s) chargé. ", libraryName, expansionName )

    -- Messages d'erreur génériques
    L["INPUT_PARM_NIL"]       = "[ERREUR] Paramètre d'entrée nul. "
    L["INVALID_TYPE"]         = "[ERREUR] Type de données d'entrée invalide. Attendu %s "

    -- Messages spécifiques aux threads
    L["HANDLE_NIL"]           = "[ERREUR] Descripteur de thread nul. "
    L["INVALID_EXE_STATE"]    = "[ERREUR] Thread[%d] est %s. "
    L["HANDLE_ILL_FORMED"]    = "[ERREUR] Descripteur de thread mal formé."
    L["HANDLE_NOT_A_THREAD"]  = "[ERREUR] Le descripteur de thread spécifié ne référence pas une coroutine."

    L["INVALID_EXE_CONTEXT"]  = "[ERREUR] L'opération nécessite un contexte de thread. "
    L["HANDLE_INVALID"]       = "[ERREUR] Descripteur invalide. Le descripteur est probablement 'mort'. "
    L["RESUME_FAILED"]        = "[ERREUR] Échec de la reprise du thread[%d] : "
    
    L["SIGNAL_QUEUE_INVALID"] = "[ERREUR] Thread[%d] Queue de signal invalide. "
    L["SIGNAL_OUT_OF_RANGE"]  = "[ERREUR] Signal hors de portée. "
    L["SIGNAL_INVALID"]       = "[ERREUR] Signal inconnu."
end
if LOCALE == "zhCN" then

    -- WoWThreads 本地化
    L["VERSION"]              = version
    L["ADDON_MESSAGE"]        = sprintf("%s (%s) 已加载。", libraryName, expansionName )

    -- 通用错误消息
    L["INPUT_PARM_NIL"]       = "[错误] 输入参数为空。"
    L["INVALID_TYPE"]         = "[错误] 输入数据类型无效。期望 %s "

    -- 线程特定消息
    L["HANDLE_NIL"]           = "[错误] 线程句柄为空。"
    L["INVALID_EXE_STATE"]    = "[错误] 线程[%d]为%s。"
    L["HANDLE_ILL_FORMED"]    = "[错误] 线程句柄格式错误。"
    L["HANDLE_NOT_A_THREAD"]  = "[错误] 指定的线程句柄不引用协程。"

    L["INVALID_EXE_CONTEXT"]  = "[错误] 操作需要线程上下文。"
    L["HANDLE_INVALID"]       = "[错误] 句柄无效。句柄可能已经‘死亡’。"
    L["RESUME_FAILED"]        = "[错误] 无法恢复线程[%d]："
    
    L["SIGNAL_QUEUE_INVALID"] = "[错误] 线程[%d]信号队列无效。"
    L["SIGNAL_OUT_OF_RANGE"]  = "[错误] 信号超出范围。"
    L["SIGNAL_INVALID"]       = "[错误] 信号未知。"
end
if LOCALE == "koKR" then

    -- WoWThreads 지역화
    L["VERSION"]              = version
    L["ADDON_MESSAGE"]        = sprintf("%s (%s) 로드됨. ", libraryName, expansionName )

    -- 일반 오류 메시지
    L["INPUT_PARM_NIL"]       = "[오류] 입력 매개변수가 nil입니다. "
    L["INVALID_TYPE"]         = "[오류] 입력 데이터 유형이 잘못되었습니다. %s 이(가) 필요합니다 "

    -- 스레드 특정 메시지
    L["HANDLE_NIL"]           = "[오류] 스레드 핸들이 nil입니다. "
    L["INVALID_EXE_STATE"]    = "[오류] 스레드[%d] 상태가 %s입니다. "
    L["HANDLE_ILL_FORMED"]    = "[오류] 스레드 핸들 형식이 잘못되었습니다."
    L["HANDLE_NOT_A_THREAD"]  = "[오류] 지정된 스레드 핸들이 코루틴을 참조하지 않습니다."

    L["INVALID_EXE_CONTEXT"]  = "[오류] 작업에 스레드 컨텍스트가 필요합니다. "
    L["HANDLE_INVALID"]       = "[오류] 핸들이 유효하지 않습니다. 핸들은 '죽었을' 가능성이 높습니다. "
    L["RESUME_FAILED"]        = "[오류] 스레드[%d] 재개 실패: "
    
    L["SIGNAL_QUEUE_INVALID"] = "[오류] 스레드[%d] 신호 큐가 유효하지 않습니다. "
    L["SIGNAL_OUT_OF_RANGE"]  = "[오류] 신호가 범위를 벗어났습니다. "
    L["SIGNAL_INVALID"]       = "[오류] 알 수 없는 신호입니다."
end
if LOCALE == "svSE" then

    -- WoWThreads Lokaliseringar
    L["VERSION"]              = version
    L["ADDON_MESSAGE"]        = sprintf("%s (%s) laddat. ", libraryName, expansionName )

    -- Generella felmeddelanden
    L["INPUT_PARM_NIL"]       = "[FEL] Inmatningsparameter är null. "
    L["INVALID_TYPE"]         = "[FEL] Ogiltig datatyp för inmatning. Förväntad %s "

    -- Trådspecifika meddelanden
    L["HANDLE_NIL"]           = "[FEL] Trådhandtag är null. "
    L["INVALID_EXE_STATE"]    = "[FEL] Tråd[%d] är %s. "
    L["HANDLE_ILL_FORMED"]    = "[FEL] Trådhandtaget är felaktigt formaterat."
    L["HANDLE_NOT_A_THREAD"]  = "[FEL] Angivet trådhandtag refererar inte till en korutin."

    L["INVALID_EXE_CONTEXT"]  = "[FEL] Operation kräver trådkontext. "
    L["HANDLE_INVALID"]       = "[FEL] Ogiltigt handtag. Handtaget är troligen 'dött.' "
    L["RESUME_FAILED"]        = "[FEL] Misslyckades med att återuppta tråd[%d]: "
    
    L["SIGNAL_QUEUE_INVALID"] = "[FEL] Tråd[%d] Ogiltig signal kö. "
    L["SIGNAL_OUT_OF_RANGE"]  = "[FEL] Signalen är utanför tillåtet intervall. "
    L["SIGNAL_INVALID"]       = "[FEL] Signalen är okänd."
end
if LOCALE == "heIL" then

    -- תרגומים ל-WoWThreads
    L["VERSION"]              = version
    L["ADDON_MESSAGE"]        = sprintf("%s (%s) נטען. ", libraryName, expansionName )

    -- הודעות שגיאה כלליות
    L["INPUT_PARM_NIL"]       = "[שגיאה] פרמטר קלט ריק. "
    L["INVALID_TYPE"]         = "[שגיאה] סוג נתוני קלט לא תקין. צפוי %s "

    -- הודעות ספציפיות לתהליכון
    L["HANDLE_NIL"]           = "[שגיאה] ידית התהליכון ריקה. "
    L["INVALID_EXE_STATE"]    = "[שגיאה] תהליכון[%d] הוא %s. "
    L["HANDLE_ILL_FORMED"]    = "[שגיאה] ידית תהליכון בעייתית."
    L["HANDLE_NOT_A_THREAD"]  = "[שגיאה] ידית התהליכון המצוינת אינה מתייחסת לשגרת הרצה."

    L["INVALID_EXE_CONTEXT"]  = "[שגיאה] הפעולה דורשת הקשר של תהליכון. "
    L["HANDLE_INVALID"]       = "[שגיאה] ידית לא תקינה. יש סבירות שהידית 'מתה.' "
    L["RESUME_FAILED"]        = "[שגיאה] נכשל בחידוש התהליכון[%d]: "
    
    L["SIGNAL_QUEUE_INVALID"] = "[שגיאה] תהליכון[%d] תור אותות לא תקין. "
    L["SIGNAL_OUT_OF_RANGE"]  = "[שגיאה] האות נמצא מחוץ לטווח. "
    L["SIGNAL_INVALID"]       = "[שגיאה] האות אינו מוכר."
end
if LOCALE == "esES" then
    -- Localizaciones de WoWThreads
    L["VERSION"]              = version
    L["ADDON_MESSAGE"]        = sprintf("%s (%s) cargado. ", libraryName, expansionName )

    -- Mensajes de Error Genéricos
    L["INPUT_PARM_NIL"]       = "%s ERROR: Parámetro de entrada nulo. "
    L["INVALID_TYPE"]         = "%s ERROR: Tipo de dato de entrada inválido. Se esperaba %s "

    -- Mensajes específicos de hilos
    L["HANDLE_NIL"]           = "%s ERROR: Identificador del hilo nulo. "
    L["INVALID_EXE_STATE"]    = "%s ERROR: Hilo[%d] está %s. "
    L["HANDLE_ILL_FORMED"]    = "%s ERROR: Identificador del hilo mal formado."
    L["HANDLE_NOT_A_THREAD"]  = "%s ERROR: El identificador de hilo especificado no hace referencia a una coroutina."

    L["INVALID_EXE_CONTEXT"]  = "%s ERROR: La operación requiere contexto de hilo. "
    L["HANDLE_INVALID"]       = "%s ERROR: Identificador inválido. El identificador probablemente esté 'muerto'. "
    L["RESUME_FAILED"]        = "%s ERROR: Fallo al reanudar el hilo[%d]: "
    
    L["SIGNAL_QUEUE_INVALID"] = "%s ERROR: Hilo[%d] Cola de señales inválida. "
    L["SIGNAL_OUT_OF_RANGE"]  = "%s ERROR: Señal fuera de rango. "
    L["SIGNAL_INVALID"]       = "%s ERROR: Señal desconocida."
end

if utils:debuggingIsEnabled() then
    DEFAULT_CHAT_FRAME:AddMessage( fileName, 0.0, 1.0, 1.0 )
end
