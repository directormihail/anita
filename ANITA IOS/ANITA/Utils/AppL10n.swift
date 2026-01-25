//
//  AppL10n.swift
//  ANITA
//
//  Lightweight in-app localization driven by onboarding language selection.
//

import Foundation

enum AppL10n {
    static let preferredLanguageKey = "anita_preferred_language_code"
    
    static func currentLanguageCode() -> String {
        UserDefaults.standard.string(forKey: preferredLanguageKey) ?? "en"
    }
    
    static func setLanguageCode(_ code: String) {
        UserDefaults.standard.set(code, forKey: preferredLanguageKey)
    }
    
    static func localeIdentifier(for code: String) -> String {
        switch code {
        case "de": return "de_DE"
        case "fr": return "fr_FR"
        case "es": return "es_ES"
        case "it": return "it_IT"
        case "pl": return "pl_PL"
        case "ru": return "ru_RU"
        case "tr": return "tr_TR"
        case "uk": return "uk_UA"
        default: return "en_US"
        }
    }
    
    static func t(_ key: String, languageCode: String? = nil) -> String {
        let lang = languageCode ?? currentLanguageCode()
        if let value = translations[lang]?[key] {
            return value
        }
        // Fallback to English
        if let value = translations["en"]?[key] {
            return value
        }
        return key
    }
    
    // MARK: - Strings
    
    private static let translations: [String: [String: String]] = [
        "en": [
            // Tabs
            "tab.chat": "Chat",
            "tab.finance": "Finance",
            "tab.settings": "Settings",
            
            // Common
            "common.back": "Back",
            "common.next": "Next",
            "common.get_started": "Get Started",
            "common.skip": "Skip",
            "common.setup": "Setup",
            "common.cancel": "Cancel",
            
            // Onboarding
            "onboarding.language.title": "Choose your language 🌍",
            "onboarding.language.subtitle": "This is how ANITA will speak to you 🗣️",
            "onboarding.currency.title": "Choose your currency 💱",
            "onboarding.currency.subtitle": "We’ll use it to format money everywhere",
            
            // Welcome / Auth
            "welcome.title": "Welcome to ANITA",
            "welcome.subtitle": "Personal Finance Assistant",
            "welcome.get_started": "Get Started",
            "welcome.sign_in": "Sign In",
            "welcome.feature.chat.title": "AI Chat",
            "welcome.feature.chat.desc": "Talk naturally, track automatically",
            "welcome.feature.finance.title": "Finance Dashboard",
            "welcome.feature.finance.desc": "See where money goes, stop leaks",
            "welcome.feature.goals.title": "Smart Goals",
            "welcome.feature.goals.desc": "AI breaks down goals into steps",
            
            // Upgrade
            "upgrade.title": "Choose your plan 🙂",
            "upgrade.subtitle": "You can always upgrade later.",
            
            // Auth / Legal
            "auth.or": "OR",
            "auth.and": "and",
            "auth.terms": "Terms of Service",
            "auth.privacy": "Privacy Policy",
            
            // Login
            "login.forgot_password": "Forgot Password?",
            "login.login": "Login",
            "login.google": "Log in with Google",
            "login.by_continuing": "By continuing, you agree to our",
            "login.email": "Email",
            "login.password": "Password",
            "login.reset.send": "Send Reset Link",
            "login.reset.help": "Enter your email address and we'll send you a password reset link.",
            
            // Sign up
            "signup.next": "Next",
            "signup.google": "Sign up with Google",
            "signup.select_currency": "Select Currency",
            "signup.signup": "Sign Up",
            "signup.confirm_password": "Confirm Password",
            "signup.by_creating": "By creating an account, you agree to our",
            
            // Upgrade (plans)
            "plans.upgrade_header": "Upgrade to Premium",
            "plans.upgrade_subheader": "Unlock all features and get the most out of ANITA",
            "plans.free": "Free",
            "plans.pro": "Pro",
            "plans.ultimate": "Ultimate",
            "plans.per_month": "/month",
            "plans.current": "Current Plan",
            "plans.most_popular": "Most Popular",
            "plans.loading": "Loading...",
            "plans.upgrade_to": "Upgrade to",
            "plans.purchase_success_title": "Purchase Successful",
            "plans.purchase_success_body": "Your subscription has been activated!",
            "plans.ok": "OK"
            ,
            // Plan features
            "plans.feature.replies_20": "20 replies per month",
            "plans.feature.basic_expense": "Basic expense analysis",
            
            "plans.feature.replies_50": "50 replies per month",
            "plans.feature.full_budget": "Full budget analysis",
            "plans.feature.financial_goals": "Financial goals",
            "plans.feature.smart_insights": "Smart insights",
            "plans.feature.faster_ai": "Faster AI responses",
            
            "plans.feature.unlimited_replies": "Unlimited replies",
            "plans.feature.advanced_analytics": "Advanced analytics",
            "plans.feature.priority_support": "Priority support",
            "plans.feature.custom_ai": "Custom AI training",
            "plans.feature.all_pro": "All Pro features"
            ,
            // Settings sections
            "settings.profile": "Profile",
            "settings.preferences": "Preferences",
            "settings.development": "Development",
            "settings.subscription": "Subscription",
            "settings.notifications": "Notifications",
            "settings.privacy_data": "Privacy & Data",
            "settings.information": "Information",
            "settings.about": "About",
            
            // Chat
            "chat.upgrade": "Upgrade",
            "chat.welcome_title": "Welcome to ANITA",
            "chat.welcome_subtitle": "Your Personal Finance Assistant",
            "chat.welcome_body": "Track expenses, set goals, and get insights about your finances. Just ask me anything or use the buttons below to get started.",
            "chat.error": "Error",
            "chat.check_goal": "Check your goal",
            "chat.check_limit": "Check your limit"
        ],
        "de": [
            "tab.chat": "Chat",
            "tab.finance": "Finanzen",
            "tab.settings": "Einstellungen",
            
            "common.back": "Zurück",
            "common.next": "Weiter",
            "common.get_started": "Los geht’s",
            "common.skip": "Überspringen",
            "common.setup": "Setup",
            "common.cancel": "Abbrechen",
            "onboarding.language.title": "Sprache wählen 🌍",
            "onboarding.language.subtitle": "So spricht ANITA mit dir 🗣️",
            "onboarding.currency.title": "Wähle deine Währung 💱",
            "onboarding.currency.subtitle": "So formatiere ich Geldbeträge für dich",
            
            "welcome.title": "Willkommen bei ANITA",
            "welcome.subtitle": "Persönlicher Finanzassistent",
            "welcome.get_started": "Los geht’s",
            "welcome.sign_in": "Anmelden",
            "welcome.feature.chat.title": "KI‑Chat",
            "welcome.feature.chat.desc": "Natürlich reden, automatisch tracken",
            "welcome.feature.finance.title": "Finanz‑Dashboard",
            "welcome.feature.finance.desc": "Ausgaben sehen, Leaks stoppen",
            "welcome.feature.goals.title": "Smarte Ziele",
            "welcome.feature.goals.desc": "KI zerlegt Ziele in Schritte",
            
            "upgrade.title": "Wähle deinen Plan 🙂",
            "upgrade.subtitle": "Du kannst jederzeit später upgraden.",
            
            "auth.or": "ODER",
            "auth.and": "und",
            "auth.terms": "Nutzungsbedingungen",
            "auth.privacy": "Datenschutz",
            
            "login.forgot_password": "Passwort vergessen?",
            "login.login": "Anmelden",
            "login.google": "Mit Google anmelden",
            "login.by_continuing": "Wenn du fortfährst, stimmst du zu:",
            "login.email": "E‑Mail",
            "login.password": "Passwort",
            "login.reset.send": "Link senden",
            "login.reset.help": "Gib deine E‑Mail ein, dann senden wir dir einen Reset‑Link.",
            
            "signup.next": "Weiter",
            "signup.google": "Mit Google registrieren",
            "signup.select_currency": "Währung wählen",
            "signup.signup": "Registrieren",
            "signup.confirm_password": "Passwort bestätigen",
            "signup.by_creating": "Mit der Kontoerstellung stimmst du zu:",
            
            "plans.upgrade_header": "Upgrade auf Premium",
            "plans.upgrade_subheader": "Schalte alle Features frei und hole das Beste aus ANITA heraus",
            "plans.free": "Kostenlos",
            "plans.pro": "Pro",
            "plans.ultimate": "Ultimate",
            "plans.per_month": "/Monat",
            "plans.current": "Aktueller Plan",
            "plans.most_popular": "Am beliebtesten",
            "plans.loading": "Lädt…",
            "plans.upgrade_to": "Upgrade auf",
            "plans.purchase_success_title": "Kauf erfolgreich",
            "plans.purchase_success_body": "Dein Abo wurde aktiviert!",
            "plans.ok": "OK"
            ,
            "plans.feature.replies_20": "20 Antworten pro Monat",
            "plans.feature.basic_expense": "Einfache Ausgabenanalyse",
            
            "plans.feature.replies_50": "50 Antworten pro Monat",
            "plans.feature.full_budget": "Vollständige Budgetanalyse",
            "plans.feature.financial_goals": "Finanzziele",
            "plans.feature.smart_insights": "Smartere Insights",
            "plans.feature.faster_ai": "Schnellere KI‑Antworten",
            
            "plans.feature.unlimited_replies": "Unbegrenzte Antworten",
            "plans.feature.advanced_analytics": "Erweiterte Analysen",
            "plans.feature.priority_support": "Prioritäts‑Support",
            "plans.feature.custom_ai": "Individuelles KI‑Training",
            "plans.feature.all_pro": "Alle Pro‑Features"
            ,
            "settings.profile": "Profil",
            "settings.preferences": "Einstellungen",
            "settings.development": "Entwicklung",
            "settings.subscription": "Abo",
            "settings.notifications": "Benachrichtigungen",
            "settings.privacy_data": "Datenschutz & Daten",
            "settings.information": "Informationen",
            "settings.about": "Über",
            
            "chat.upgrade": "Upgrade",
            "chat.welcome_title": "Willkommen bei ANITA",
            "chat.welcome_subtitle": "Dein persönlicher Finanzassistent",
            "chat.welcome_body": "Tracke Ausgaben, setze Ziele und erhalte Insights zu deinen Finanzen. Frag mich einfach oder nutze die Buttons unten, um zu starten.",
            "chat.error": "Fehler",
            "chat.check_goal": "Ziel prüfen",
            "chat.check_limit": "Limit prüfen"
        ],
        "es": [
            "tab.chat": "Chat",
            "tab.finance": "Finanzas",
            "tab.settings": "Ajustes",
            
            "common.back": "Atrás",
            "common.next": "Siguiente",
            "common.get_started": "Empezar",
            "common.skip": "Saltar",
            "common.setup": "Setup",
            "common.cancel": "Cancelar",
            "onboarding.language.title": "Elige tu idioma 🌍",
            "onboarding.language.subtitle": "Así te hablará ANITA 🗣️",
            "onboarding.currency.title": "Elige tu moneda 💱",
            "onboarding.currency.subtitle": "La usaré para dar formato al dinero",
            
            "welcome.title": "Bienvenido a ANITA",
            "welcome.subtitle": "Asistente de finanzas personales",
            "welcome.get_started": "Empezar",
            "welcome.sign_in": "Iniciar sesión",
            "welcome.feature.chat.title": "Chat con IA",
            "welcome.feature.chat.desc": "Habla natural, registra automático",
            "welcome.feature.finance.title": "Panel de finanzas",
            "welcome.feature.finance.desc": "Ve tus gastos y evita fugas",
            "welcome.feature.goals.title": "Metas inteligentes",
            "welcome.feature.goals.desc": "La IA divide metas en pasos",
            
            "upgrade.title": "Elige tu plan 🙂",
            "upgrade.subtitle": "Puedes mejorar más tarde cuando quieras.",
            
            "auth.or": "O",
            "auth.and": "y",
            "auth.terms": "Términos de servicio",
            "auth.privacy": "Política de privacidad",
            
            "login.forgot_password": "¿Olvidaste tu contraseña?",
            "login.login": "Entrar",
            "login.google": "Entrar con Google",
            "login.by_continuing": "Al continuar, aceptas nuestros",
            "login.email": "Correo",
            "login.password": "Contraseña",
            "login.reset.send": "Enviar enlace",
            "login.reset.help": "Ingresa tu correo y te enviaremos un enlace para restablecer la contraseña.",
            
            "signup.next": "Siguiente",
            "signup.google": "Registrarse con Google",
            "signup.select_currency": "Seleccionar moneda",
            "signup.signup": "Crear cuenta",
            "signup.confirm_password": "Confirmar contraseña",
            "signup.by_creating": "Al crear una cuenta, aceptas nuestros",
            
            "plans.upgrade_header": "Mejora a Premium",
            "plans.upgrade_subheader": "Desbloquea todo y aprovecha ANITA al máximo",
            "plans.free": "Gratis",
            "plans.pro": "Pro",
            "plans.ultimate": "Ultimate",
            "plans.per_month": "/mes",
            "plans.current": "Plan actual",
            "plans.most_popular": "Más popular",
            "plans.loading": "Cargando…",
            "plans.upgrade_to": "Mejorar a",
            "plans.purchase_success_title": "Compra exitosa",
            "plans.purchase_success_body": "¡Tu suscripción está activa!",
            "plans.ok": "OK"
            ,
            "plans.feature.replies_20": "20 respuestas al mes",
            "plans.feature.basic_expense": "Análisis básico de gastos",
            
            "plans.feature.replies_50": "50 respuestas al mes",
            "plans.feature.full_budget": "Análisis completo de presupuesto",
            "plans.feature.financial_goals": "Metas financieras",
            "plans.feature.smart_insights": "Insights inteligentes",
            "plans.feature.faster_ai": "Respuestas de IA más rápidas",
            
            "plans.feature.unlimited_replies": "Respuestas ilimitadas",
            "plans.feature.advanced_analytics": "Analíticas avanzadas",
            "plans.feature.priority_support": "Soporte prioritario",
            "plans.feature.custom_ai": "Entrenamiento de IA personalizado",
            "plans.feature.all_pro": "Todas las funciones Pro"
            ,
            "settings.profile": "Perfil",
            "settings.preferences": "Preferencias",
            "settings.development": "Desarrollo",
            "settings.subscription": "Suscripción",
            "settings.notifications": "Notificaciones",
            "settings.privacy_data": "Privacidad y datos",
            "settings.information": "Información",
            "settings.about": "Acerca de",
            
            "chat.upgrade": "Mejorar",
            "chat.welcome_title": "Bienvenido a ANITA",
            "chat.welcome_subtitle": "Tu asistente de finanzas personales",
            "chat.welcome_body": "Registra gastos, define metas y obtén insights sobre tus finanzas. Pregúntame lo que sea o usa los botones de abajo para empezar.",
            "chat.error": "Error",
            "chat.check_goal": "Revisar tu meta",
            "chat.check_limit": "Revisar tu límite"
        ],
        "it": [
            "tab.chat": "Chat",
            "tab.finance": "Finanze",
            "tab.settings": "Impostazioni",
            
            "common.back": "Indietro",
            "common.next": "Avanti",
            "common.get_started": "Inizia",
            "common.skip": "Salta",
            "common.setup": "Setup",
            "common.cancel": "Annulla",
            "onboarding.language.title": "Scegli la lingua 🌍",
            "onboarding.language.subtitle": "Così ANITA parlerà con te 🗣️",
            "onboarding.currency.title": "Scegli la valuta 💱",
            "onboarding.currency.subtitle": "La userò per formattare gli importi",
            
            "welcome.title": "Benvenuto su ANITA",
            "welcome.subtitle": "Assistente di finanza personale",
            "welcome.get_started": "Inizia",
            "welcome.sign_in": "Accedi",
            "welcome.feature.chat.title": "Chat IA",
            "welcome.feature.chat.desc": "Parla naturale, traccia automatico",
            "welcome.feature.finance.title": "Dashboard finanze",
            "welcome.feature.finance.desc": "Vedi dove vanno i soldi, stop perdite",
            "welcome.feature.goals.title": "Obiettivi smart",
            "welcome.feature.goals.desc": "L’IA divide gli obiettivi in passi",
            
            "upgrade.title": "Scegli il tuo piano 🙂",
            "upgrade.subtitle": "Puoi fare l’upgrade più tardi quando vuoi.",
            
            "auth.or": "OPPURE",
            "auth.and": "e",
            "auth.terms": "Termini di servizio",
            "auth.privacy": "Privacy",
            
            "login.forgot_password": "Password dimenticata?",
            "login.login": "Accedi",
            "login.google": "Accedi con Google",
            "login.by_continuing": "Continuando, accetti i nostri",
            "login.email": "Email",
            "login.password": "Password",
            "login.reset.send": "Invia link",
            "login.reset.help": "Inserisci la tua email e ti invieremo un link per reimpostare la password.",
            
            "signup.next": "Avanti",
            "signup.google": "Registrati con Google",
            "signup.select_currency": "Seleziona valuta",
            "signup.signup": "Registrati",
            "signup.confirm_password": "Conferma password",
            "signup.by_creating": "Creando un account, accetti i nostri",
            
            "plans.upgrade_header": "Passa a Premium",
            "plans.upgrade_subheader": "Sblocca tutto e ottieni il massimo da ANITA",
            "plans.free": "Gratis",
            "plans.pro": "Pro",
            "plans.ultimate": "Ultimate",
            "plans.per_month": "/mese",
            "plans.current": "Piano attuale",
            "plans.most_popular": "Più popolare",
            "plans.loading": "Caricamento…",
            "plans.upgrade_to": "Passa a",
            "plans.purchase_success_title": "Acquisto riuscito",
            "plans.purchase_success_body": "Il tuo abbonamento è attivo!",
            "plans.ok": "OK"
            ,
            "plans.feature.replies_20": "20 risposte al mese",
            "plans.feature.basic_expense": "Analisi spese di base",
            
            "plans.feature.replies_50": "50 risposte al mese",
            "plans.feature.full_budget": "Analisi budget completa",
            "plans.feature.financial_goals": "Obiettivi finanziari",
            "plans.feature.smart_insights": "Insight intelligenti",
            "plans.feature.faster_ai": "Risposte AI più rapide",
            
            "plans.feature.unlimited_replies": "Risposte illimitate",
            "plans.feature.advanced_analytics": "Analisi avanzate",
            "plans.feature.priority_support": "Supporto prioritario",
            "plans.feature.custom_ai": "Training AI personalizzato",
            "plans.feature.all_pro": "Tutte le funzioni Pro"
            ,
            "settings.profile": "Profilo",
            "settings.preferences": "Preferenze",
            "settings.development": "Sviluppo",
            "settings.subscription": "Abbonamento",
            "settings.notifications": "Notifiche",
            "settings.privacy_data": "Privacy e dati",
            "settings.information": "Informazioni",
            "settings.about": "Info",
            
            "chat.upgrade": "Upgrade",
            "chat.welcome_title": "Benvenuto su ANITA",
            "chat.welcome_subtitle": "Il tuo assistente di finanza personale",
            "chat.welcome_body": "Traccia spese, imposta obiettivi e ottieni insight sulle tue finanze. Chiedimi qualsiasi cosa o usa i pulsanti qui sotto per iniziare.",
            "chat.error": "Errore",
            "chat.check_goal": "Controlla il tuo obiettivo",
            "chat.check_limit": "Controlla il tuo limite"
        ],
        "ru": [
            "tab.chat": "Чат",
            "tab.finance": "Финансы",
            "tab.settings": "Настройки",
            
            "common.back": "Назад",
            "common.next": "Далее",
            "common.get_started": "Начать",
            "common.skip": "Пропустить",
            "common.setup": "Setup",
            "common.cancel": "Отмена",
            "onboarding.language.title": "Выбери язык 🌍",
            "onboarding.language.subtitle": "Так ANITA будет общаться с тобой 🗣️",
            "onboarding.currency.title": "Выбери валюту 💱",
            "onboarding.currency.subtitle": "Я буду использовать её для форматирования сумм",
            
            "welcome.title": "Добро пожаловать в ANITA",
            "welcome.subtitle": "Персональный финансовый помощник",
            "welcome.get_started": "Начать",
            "welcome.sign_in": "Войти",
            "welcome.feature.chat.title": "ИИ‑чат",
            "welcome.feature.chat.desc": "Говори естественно — учет сам",
            "welcome.feature.finance.title": "Финансовая панель",
            "welcome.feature.finance.desc": "Где уходят деньги — без утечек",
            "welcome.feature.goals.title": "Умные цели",
            "welcome.feature.goals.desc": "ИИ разбивает цель на шаги",
            
            "upgrade.title": "Выберите план 🙂",
            "upgrade.subtitle": "Вы всегда сможете обновиться позже.",
            
            "auth.or": "ИЛИ",
            "auth.and": "и",
            "auth.terms": "Условия использования",
            "auth.privacy": "Политика конфиденциальности",
            
            "login.forgot_password": "Забыли пароль?",
            "login.login": "Войти",
            "login.google": "Войти через Google",
            "login.by_continuing": "Продолжая, вы соглашаетесь с",
            "login.email": "Email",
            "login.password": "Пароль",
            "login.reset.send": "Отправить ссылку",
            "login.reset.help": "Введите email — мы отправим ссылку для сброса пароля.",
            
            "signup.next": "Далее",
            "signup.google": "Регистрация через Google",
            "signup.select_currency": "Выберите валюту",
            "signup.signup": "Создать аккаунт",
            "signup.confirm_password": "Подтвердите пароль",
            "signup.by_creating": "Создавая аккаунт, вы соглашаетесь с",
            
            "plans.upgrade_header": "Премиум‑доступ",
            "plans.upgrade_subheader": "Откройте все функции и получите максимум от ANITA",
            "plans.free": "Бесплатно",
            "plans.pro": "Pro",
            "plans.ultimate": "Ultimate",
            "plans.per_month": "/мес",
            "plans.current": "Текущий план",
            "plans.most_popular": "Самый популярный",
            "plans.loading": "Загрузка…",
            "plans.upgrade_to": "Обновиться до",
            "plans.purchase_success_title": "Покупка успешна",
            "plans.purchase_success_body": "Подписка активирована!",
            "plans.ok": "OK"
            ,
            "plans.feature.replies_20": "20 ответов в месяц",
            "plans.feature.basic_expense": "Базовый анализ расходов",
            
            "plans.feature.replies_50": "50 ответов в месяц",
            "plans.feature.full_budget": "Полный анализ бюджета",
            "plans.feature.financial_goals": "Финансовые цели",
            "plans.feature.smart_insights": "Умные инсайты",
            "plans.feature.faster_ai": "Более быстрые ответы ИИ",
            
            "plans.feature.unlimited_replies": "Безлимитные ответы",
            "plans.feature.advanced_analytics": "Продвинутая аналитика",
            "plans.feature.priority_support": "Приоритетная поддержка",
            "plans.feature.custom_ai": "Персональное обучение ИИ",
            "plans.feature.all_pro": "Все функции Pro"
            ,
            "settings.profile": "Профиль",
            "settings.preferences": "Предпочтения",
            "settings.development": "Разработка",
            "settings.subscription": "Подписка",
            "settings.notifications": "Уведомления",
            "settings.privacy_data": "Приватность и данные",
            "settings.information": "Информация",
            "settings.about": "О приложении",
            
            "chat.upgrade": "Апгрейд",
            "chat.welcome_title": "Добро пожаловать в ANITA",
            "chat.welcome_subtitle": "Ваш помощник по личным финансам",
            "chat.welcome_body": "Учитывайте расходы, ставьте цели и получайте инсайты по финансам. Просто спросите меня или нажмите кнопки ниже, чтобы начать.",
            "chat.error": "Ошибка",
            "chat.check_goal": "Проверить цель",
            "chat.check_limit": "Проверить лимит"
        ],
        "uk": [
            "tab.chat": "Чат",
            "tab.finance": "Фінанси",
            "tab.settings": "Налаштування",
            
            "common.back": "Назад",
            "common.next": "Далі",
            "common.get_started": "Почати",
            "common.skip": "Пропустити",
            "common.setup": "Setup",
            "common.cancel": "Скасувати",
            "onboarding.language.title": "Обери мову 🌍",
            "onboarding.language.subtitle": "Так ANITA спілкуватиметься з тобою 🗣️",
            "onboarding.currency.title": "Обери валюту 💱",
            "onboarding.currency.subtitle": "Я використаю її для форматування сум",
            
            "welcome.title": "Ласкаво просимо до ANITA",
            "welcome.subtitle": "Персональний фінансовий помічник",
            "welcome.get_started": "Почати",
            "welcome.sign_in": "Увійти",
            "welcome.feature.chat.title": "ШІ‑чат",
            "welcome.feature.chat.desc": "Говори природно — облік сам",
            "welcome.feature.finance.title": "Фінансова панель",
            "welcome.feature.finance.desc": "Куди йдуть гроші — без витоків",
            "welcome.feature.goals.title": "Розумні цілі",
            "welcome.feature.goals.desc": "ШІ ділить ціль на кроки",
            
            "upgrade.title": "Обери план 🙂",
            "upgrade.subtitle": "Ти завжди зможеш оновитись пізніше.",
            
            "auth.or": "АБО",
            "auth.and": "і",
            "auth.terms": "Умови використання",
            "auth.privacy": "Політика конфіденційності",
            
            "login.forgot_password": "Забули пароль?",
            "login.login": "Увійти",
            "login.google": "Увійти через Google",
            "login.by_continuing": "Продовжуючи, ти погоджуєшся з",
            "login.email": "Email",
            "login.password": "Пароль",
            "login.reset.send": "Надіслати посилання",
            "login.reset.help": "Введи email — ми надішлемо посилання для скидання пароля.",
            
            "signup.next": "Далі",
            "signup.google": "Реєстрація через Google",
            "signup.select_currency": "Обери валюту",
            "signup.signup": "Створити акаунт",
            "signup.confirm_password": "Підтвердь пароль",
            "signup.by_creating": "Створюючи акаунт, ти погоджуєшся з",
            
            "plans.upgrade_header": "Преміум‑доступ",
            "plans.upgrade_subheader": "Відкрий всі функції та отримай максимум від ANITA",
            "plans.free": "Безкоштовно",
            "plans.pro": "Pro",
            "plans.ultimate": "Ultimate",
            "plans.per_month": "/міс",
            "plans.current": "Поточний план",
            "plans.most_popular": "Найпопулярніший",
            "plans.loading": "Завантаження…",
            "plans.upgrade_to": "Оновитися до",
            "plans.purchase_success_title": "Покупка успішна",
            "plans.purchase_success_body": "Підписку активовано!",
            "plans.ok": "OK"
            ,
            "plans.feature.replies_20": "20 відповідей на місяць",
            "plans.feature.basic_expense": "Базовий аналіз витрат",
            
            "plans.feature.replies_50": "50 відповідей на місяць",
            "plans.feature.full_budget": "Повний аналіз бюджету",
            "plans.feature.financial_goals": "Фінансові цілі",
            "plans.feature.smart_insights": "Розумні інсайти",
            "plans.feature.faster_ai": "Швидші відповіді ШІ",
            
            "plans.feature.unlimited_replies": "Необмежені відповіді",
            "plans.feature.advanced_analytics": "Розширена аналітика",
            "plans.feature.priority_support": "Пріоритетна підтримка",
            "plans.feature.custom_ai": "Персональне навчання ШІ",
            "plans.feature.all_pro": "Усі функції Pro"
            ,
            "settings.profile": "Профіль",
            "settings.preferences": "Налаштування",
            "settings.development": "Розробка",
            "settings.subscription": "Підписка",
            "settings.notifications": "Сповіщення",
            "settings.privacy_data": "Приватність і дані",
            "settings.information": "Інформація",
            "settings.about": "Про застосунок",
            
            "chat.upgrade": "Оновити",
            "chat.welcome_title": "Ласкаво просимо до ANITA",
            "chat.welcome_subtitle": "Твій помічник з фінансів",
            "chat.welcome_body": "Веди облік витрат, став цілі та отримуй інсайти про фінанси. Просто запитай мене або натисни кнопки нижче, щоб почати.",
            "chat.error": "Помилка",
            "chat.check_goal": "Перевірити ціль",
            "chat.check_limit": "Перевірити ліміт"
        ],
        "fr": [
            "tab.chat": "Chat",
            "tab.finance": "Finances",
            "tab.settings": "Paramètres",
            
            "common.back": "Retour",
            "common.next": "Suivant",
            "common.get_started": "Commencer",
            "common.skip": "Passer",
            "common.setup": "Configuration",
            "common.cancel": "Annuler",
            
            "onboarding.language.title": "Choisis ta langue 🌍",
            "onboarding.language.subtitle": "C’est ainsi qu’ANITA te parlera 🗣️",
            "onboarding.currency.title": "Choisis ta devise 💱",
            "onboarding.currency.subtitle": "Je l’utiliserai pour formater les montants",
            
            "welcome.title": "Bienvenue sur ANITA",
            "welcome.subtitle": "Assistant de finances personnelles",
            "welcome.get_started": "Commencer",
            "welcome.sign_in": "Se connecter",
            "welcome.feature.chat.title": "Chat IA",
            "welcome.feature.chat.desc": "Parle naturellement, suivi automatique",
            "welcome.feature.finance.title": "Tableau de bord",
            "welcome.feature.finance.desc": "Vois où va l’argent, stoppe les fuites",
            "welcome.feature.goals.title": "Objectifs intelligents",
            "welcome.feature.goals.desc": "L’IA découpe les objectifs en étapes",
            
            "upgrade.title": "Choisis ton plan 🙂",
            "upgrade.subtitle": "Tu pourras changer plus tard si tu veux.",
            
            "auth.or": "OU",
            "auth.and": "et",
            "auth.terms": "Conditions d’utilisation",
            "auth.privacy": "Politique de confidentialité",
            
            "login.forgot_password": "Mot de passe oublié ?",
            "login.login": "Se connecter",
            "login.google": "Se connecter avec Google",
            "login.by_continuing": "En continuant, tu acceptes nos",
            "login.email": "E-mail",
            "login.password": "Mot de passe",
            "login.reset.send": "Envoyer le lien",
            "login.reset.help": "Entre ton e-mail et on t’enverra un lien de réinitialisation.",
            
            "signup.next": "Suivant",
            "signup.google": "S’inscrire avec Google",
            "signup.select_currency": "Choisir la devise",
            "signup.signup": "Créer un compte",
            "signup.confirm_password": "Confirmer le mot de passe",
            "signup.by_creating": "En créant un compte, tu acceptes nos",
            
            // Upgrade (plans)
            "plans.upgrade_header": "Passe à Premium",
            "plans.upgrade_subheader": "Débloque toutes les fonctionnalités et profite d’ANITA au maximum",
            "plans.free": "Gratuit",
            "plans.pro": "Pro",
            "plans.ultimate": "Ultimate",
            "plans.per_month": "/mois",
            "plans.current": "Plan actuel",
            "plans.most_popular": "Le plus populaire",
            "plans.loading": "Chargement…",
            "plans.upgrade_to": "Passer à",
            "plans.purchase_success_title": "Achat réussi",
            "plans.purchase_success_body": "Ton abonnement est activé !",
            "plans.ok": "OK",
            
            "plans.feature.replies_20": "20 réponses par mois",
            "plans.feature.basic_expense": "Analyse basique des dépenses",
            "plans.feature.replies_50": "50 réponses par mois",
            "plans.feature.full_budget": "Analyse complète du budget",
            "plans.feature.financial_goals": "Objectifs financiers",
            "plans.feature.smart_insights": "Insights intelligents",
            "plans.feature.faster_ai": "Réponses IA plus rapides",
            "plans.feature.unlimited_replies": "Réponses illimitées",
            "plans.feature.advanced_analytics": "Analyses avancées",
            "plans.feature.priority_support": "Support prioritaire",
            "plans.feature.custom_ai": "Entraînement IA personnalisé",
            "plans.feature.all_pro": "Toutes les fonctionnalités Pro"
        ],
        "pl": [
            "tab.chat": "Chat",
            "tab.finance": "Finanse",
            "tab.settings": "Ustawienia",
            
            "common.back": "Wstecz",
            "common.next": "Dalej",
            "common.get_started": "Zaczynajmy",
            "common.skip": "Pomiń",
            "common.setup": "Ustawienia",
            "common.cancel": "Anuluj",
            
            "onboarding.language.title": "Wybierz język 🌍",
            "onboarding.language.subtitle": "Tak ANITA będzie z Tobą rozmawiać 🗣️",
            "onboarding.currency.title": "Wybierz walutę 💱",
            "onboarding.currency.subtitle": "Użyję jej do formatowania kwot",
            
            "welcome.title": "Witaj w ANITA",
            "welcome.subtitle": "Asystent finansów osobistych",
            "welcome.get_started": "Zaczynajmy",
            "welcome.sign_in": "Zaloguj się",
            "welcome.feature.chat.title": "Chat AI",
            "welcome.feature.chat.desc": "Rozmawiaj naturalnie, śledź automatycznie",
            "welcome.feature.finance.title": "Panel finansów",
            "welcome.feature.finance.desc": "Zobacz gdzie uciekają pieniądze",
            "welcome.feature.goals.title": "Inteligentne cele",
            "welcome.feature.goals.desc": "AI dzieli cele na kroki",
            
            "upgrade.title": "Wybierz plan 🙂",
            "upgrade.subtitle": "Zawsze możesz później zmienić.",
            
            "auth.or": "LUB",
            "auth.and": "i",
            "auth.terms": "Warunki korzystania",
            "auth.privacy": "Polityka prywatności",
            
            "login.forgot_password": "Nie pamiętasz hasła?",
            "login.login": "Zaloguj się",
            "login.google": "Zaloguj się przez Google",
            "login.by_continuing": "Kontynuując, akceptujesz nasze",
            "login.email": "Email",
            "login.password": "Hasło",
            "login.reset.send": "Wyślij link",
            "login.reset.help": "Wpisz email, a wyślemy link do resetu hasła.",
            
            "signup.next": "Dalej",
            "signup.google": "Zarejestruj się przez Google",
            "signup.select_currency": "Wybierz walutę",
            "signup.signup": "Zarejestruj się",
            "signup.confirm_password": "Potwierdź hasło",
            "signup.by_creating": "Tworząc konto, akceptujesz nasze",
            
            // Upgrade (plans)
            "plans.upgrade_header": "Przejdź na Premium",
            "plans.upgrade_subheader": "Odblokuj wszystkie funkcje i wykorzystaj ANITA w pełni",
            "plans.free": "Darmowy",
            "plans.pro": "Pro",
            "plans.ultimate": "Ultimate",
            "plans.per_month": "/mies.",
            "plans.current": "Aktualny plan",
            "plans.most_popular": "Najpopularniejszy",
            "plans.loading": "Ładowanie…",
            "plans.upgrade_to": "Przejdź na",
            "plans.purchase_success_title": "Zakup udany",
            "plans.purchase_success_body": "Twoja subskrypcja jest aktywna!",
            "plans.ok": "OK",
            
            "plans.feature.replies_20": "20 odpowiedzi na miesiąc",
            "plans.feature.basic_expense": "Podstawowa analiza wydatków",
            "plans.feature.replies_50": "50 odpowiedzi na miesiąc",
            "plans.feature.full_budget": "Pełna analiza budżetu",
            "plans.feature.financial_goals": "Cele finansowe",
            "plans.feature.smart_insights": "Inteligentne wskazówki",
            "plans.feature.faster_ai": "Szybsze odpowiedzi AI",
            "plans.feature.unlimited_replies": "Nieograniczone odpowiedzi",
            "plans.feature.advanced_analytics": "Zaawansowana analityka",
            "plans.feature.priority_support": "Priorytetowe wsparcie",
            "plans.feature.custom_ai": "Personalizowane szkolenie AI",
            "plans.feature.all_pro": "Wszystkie funkcje Pro"
        ],
        "tr": [
            "tab.chat": "Sohbet",
            "tab.finance": "Finans",
            "tab.settings": "Ayarlar",
            
            "common.back": "Geri",
            "common.next": "İleri",
            "common.get_started": "Başla",
            "common.skip": "Atla",
            "common.setup": "Kurulum",
            "common.cancel": "İptal",
            
            "onboarding.language.title": "Dilini seç 🌍",
            "onboarding.language.subtitle": "ANITA seninle böyle konuşacak 🗣️",
            "onboarding.currency.title": "Para birimini seç 💱",
            "onboarding.currency.subtitle": "Tutarları bu para birimiyle göstereceğim",
            
            "welcome.title": "ANITA’ya hoş geldin",
            "welcome.subtitle": "Kişisel Finans Asistanı",
            "welcome.get_started": "Başla",
            "welcome.sign_in": "Giriş yap",
            "welcome.feature.chat.title": "Yapay Zekâ Sohbeti",
            "welcome.feature.chat.desc": "Doğal konuş, otomatik takip",
            "welcome.feature.finance.title": "Finans Paneli",
            "welcome.feature.finance.desc": "Paranın nereye gittiğini gör",
            "welcome.feature.goals.title": "Akıllı Hedefler",
            "welcome.feature.goals.desc": "YZ hedefleri adımlara böler",
            
            "upgrade.title": "Planını seç 🙂",
            "upgrade.subtitle": "İstediğin zaman sonra yükseltebilirsin.",
            
            "auth.or": "VEYA",
            "auth.and": "ve",
            "auth.terms": "Hizmet Şartları",
            "auth.privacy": "Gizlilik Politikası",
            
            "login.forgot_password": "Şifreni mi unuttun?",
            "login.login": "Giriş yap",
            "login.google": "Google ile giriş yap",
            "login.by_continuing": "Devam ederek şunları kabul edersin",
            "login.email": "E-posta",
            "login.password": "Şifre",
            "login.reset.send": "Bağlantıyı gönder",
            "login.reset.help": "E-postanı gir, şifre sıfırlama bağlantısı gönderelim.",
            
            "signup.next": "İleri",
            "signup.google": "Google ile kayıt ol",
            "signup.select_currency": "Para birimini seç",
            "signup.signup": "Kaydol",
            "signup.confirm_password": "Şifreyi doğrula",
            "signup.by_creating": "Hesap oluşturarak şunları kabul edersin",
            
            // Upgrade (plans)
            "plans.upgrade_header": "Premium’e geç",
            "plans.upgrade_subheader": "Tüm özellikleri aç ve ANITA’dan en iyi şekilde yararlan",
            "plans.free": "Ücretsiz",
            "plans.pro": "Pro",
            "plans.ultimate": "Ultimate",
            "plans.per_month": "/ay",
            "plans.current": "Mevcut Plan",
            "plans.most_popular": "En Popüler",
            "plans.loading": "Yükleniyor…",
            "plans.upgrade_to": "Şuna yükselt",
            "plans.purchase_success_title": "Satın alma başarılı",
            "plans.purchase_success_body": "Aboneliğin etkinleştirildi!",
            "plans.ok": "Tamam",
            
            "plans.feature.replies_20": "Ayda 20 yanıt",
            "plans.feature.basic_expense": "Temel gider analizi",
            "plans.feature.replies_50": "Ayda 50 yanıt",
            "plans.feature.full_budget": "Tam bütçe analizi",
            "plans.feature.financial_goals": "Finansal hedefler",
            "plans.feature.smart_insights": "Akıllı içgörüler",
            "plans.feature.faster_ai": "Daha hızlı AI yanıtları",
            "plans.feature.unlimited_replies": "Sınırsız yanıt",
            "plans.feature.advanced_analytics": "Gelişmiş analizler",
            "plans.feature.priority_support": "Öncelikli destek",
            "plans.feature.custom_ai": "Özel AI eğitimi",
            "plans.feature.all_pro": "Tüm Pro özellikleri"
        ],
    ]
}

